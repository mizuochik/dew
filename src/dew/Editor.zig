const std = @import("std");
const os = std.os;
const io = std.io;
const ascii = std.ascii;
const mem = std.mem;
const heap = std.heap;
const debug = std.debug;
const fmt = std.fmt;
const fs = std.fs;
const unicode = std.unicode;
const testing = std.testing;
const dew = @import("../dew.zig");
const c = dew.c;

const darwin_ECHO: os.tcflag_t = 0x8;
const darwin_ICANON: os.tcflag_t = 0x100;
const darwin_ISIG: os.tcflag_t = 0x80;
const darwin_IXON: os.tcflag_t = 0x200;
const darwin_IEXTEN: os.tcflag_t = 0x400;
const darwin_ICRNL: os.tcflag_t = 0x100;
const darwin_OPOST: os.tcflag_t = 0x1;
const darwin_BRKINT: os.tcflag_t = 0x2;
const darwin_INPCK: os.tcflag_t = 0x10;
const darwin_ISTRIP: os.tcflag_t = 0x20;
const darwin_CS8: os.tcflag_t = 0x300;

const ControlKeys = enum(u8) {
    DEL = 127,
    RETURN = 0x0d,
};

const Editor = @This();

const Config = struct {
    orig_termios: os.termios,
    screen_size: WindowSize,
    c_x: usize = 0,
    c_y: usize = 0,
    c_x_pre: usize = 0,
    row_offset: usize = 0,
    rows: std.ArrayList(dew.UnicodeString),
    file_path: ?[]const u8 = null,
    status_message: []const u8,
};

const Key = union(enum) {
    plain: u21,
    control: u8,
    arrow: Arrow,
};

const Arrow = enum {
    up,
    down,
    right,
    left,
    begin_of_line,
    end_of_line,
    next_page,
    prev_page,
};

allocator: mem.Allocator,
config: Config,
buffer: dew.Buffer,
buffer_view: dew.BufferView,

pub fn init(allocator: mem.Allocator) !Editor {
    const orig = try enableRawMode();
    const size = try getWindowSize();
    const status = try fmt.allocPrint(allocator, "Initialized", .{});
    errdefer allocator.free(status);
    const buffer = dew.Buffer.init(allocator);
    errdefer buffer.deinit();
    var editor = Editor{
        .allocator = allocator,
        .config = Config{
            .orig_termios = orig,
            .screen_size = size,
            .rows = std.ArrayList(dew.UnicodeString).init(allocator),
            .status_message = status,
        },
        .buffer = buffer,
        .buffer_view = undefined,
    };
    const buffer_view = try dew.BufferView.init(allocator, &editor.buffer, size.cols, size.rows);
    errdefer buffer_view.deinit();
    editor.buffer_view = buffer_view;
    return editor;
}

pub fn deinit(self: *const Editor) !void {
    try self.disableRawMode();
    try self.doRender(clearScreen);
    self.allocator.free(self.config.status_message);
    self.config.rows.deinit();
    self.buffer.deinit();
    self.buffer_view.deinit();
}

pub fn openFile(self: *Editor, path: []const u8) !void {
    var f = try fs.cwd().openFile(path, .{});
    var reader = f.reader();

    var new_rows = std.ArrayList(dew.UnicodeString).init(self.allocator);
    errdefer {
        for (new_rows.items) |row| row.deinit();
        new_rows.deinit();
    }

    var new_buffer = dew.Buffer.init(self.allocator);
    errdefer new_buffer.deinit();

    while (true) {
        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();
        reader.streamUntilDelimiter(buf.writer(), '\n', null) catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };
        var new_row = try dew.UnicodeString.init(self.allocator);
        errdefer new_row.deinit();
        try new_row.appendSlice(buf.items);
        try new_rows.append(new_row);
        try new_buffer.rows.append(new_row);
    }

    var last_row = try dew.UnicodeString.init(self.allocator);
    errdefer last_row.deinit();
    try new_rows.append(last_row);
    try new_buffer.rows.append(last_row);

    self.buffer.deinit();
    self.buffer = new_buffer;
    self.config.rows.deinit();
    self.config.rows = new_rows;
    self.config.file_path = path;
}

pub fn saveFile(self: *Editor) !void {
    var f = try fs.cwd().createFile(self.config.file_path.?, .{});
    defer f.close();
    for (self.config.rows.items, 0..) |row, i| {
        _ = try f.write(row.buffer.items);
        if (i < self.config.rows.items.len - 1)
            _ = try f.write("\n");
    }
    const new_status = try fmt.allocPrint(self.allocator, "Saved: {s}", .{self.config.file_path.?});
    errdefer self.allocator.free(new_status);
    self.setStatusMessage(new_status);
}

pub fn setStatusMessage(self: *Editor, status_message: []const u8) void {
    self.allocator.free(self.config.status_message);
    self.config.status_message = status_message;
}

pub fn run(self: *Editor) !void {
    try self.doRender(clearScreen);
    while (true) {
        try self.doRender(refreshScreen);
        const key = try readKey();
        self.processKeypress(key) catch |err| switch (err) {
            error.Quit => return,
            else => return err,
        };
    }
}

fn ctrlKey(comptime key: u8) u8 {
    return key & 0x1f;
}

fn readKey() !Key {
    const h = try io.getStdIn().reader().readByte();
    if (h == 0x1b) {
        const esc = try io.getStdIn().reader().readByte();
        if (esc == '[') {
            const a = try io.getStdIn().reader().readByte();
            return .{
                .arrow = switch (a) {
                    'A' => .up,
                    'B' => .down,
                    'C' => .right,
                    'D' => .left,
                    else => unreachable,
                },
            };
        }
        unreachable;
    }
    if (ascii.isControl(h)) {
        return switch (h) {
            ctrlKey('p') => .{ .arrow = .up },
            ctrlKey('n') => .{ .arrow = .down },
            ctrlKey('f') => .{ .arrow = .right },
            ctrlKey('b') => .{ .arrow = .left },
            ctrlKey('a') => .{ .arrow = .begin_of_line },
            ctrlKey('e') => .{ .arrow = .end_of_line },
            ctrlKey('y') => .{ .arrow = .prev_page },
            ctrlKey('v') => .{ .arrow = .next_page },
            else => .{ .control = h },
        };
    }
    var buf: [4]u8 = undefined;
    buf[0] = h;
    const l = try unicode.utf8ByteSequenceLength(h);
    for (1..l) |i| {
        buf[i] = try io.getStdIn().reader().readByte();
    }
    return .{ .plain = try unicode.utf8Decode(buf[0..l]) };
}

fn processKeypress(self: *Editor, key: Key) !void {
    switch (key) {
        .control => |k| switch (k) {
            ctrlKey('q') => return error.Quit,
            ctrlKey('s') => try self.saveFile(),
            ctrlKey('k') => try self.killLine(),
            ctrlKey('d') => try self.deleteChar(),
            @enumToInt(ControlKeys.DEL), ctrlKey('h') => {
                try self.deleteBackwardChar();
            },
            @enumToInt(ControlKeys.RETURN) => {
                try self.breakLine();
            },
            else => {},
        },
        .plain => |k| try self.insertChar(k),
        .arrow => |k| self.moveCursor(k),
    }
}

fn moveCursor(self: *Editor, k: Arrow) void {
    switch (k) {
        .up => self.moveToPreviousLine(),
        .down => self.moveToNextLine(),
        .left => _ = self.moveBackwardChar(),
        .right => self.moveForwardChar(),
        .begin_of_line => {
            self.config.c_x_pre = 0;
        },
        .end_of_line => {
            const row = self.config.rows.items[self.config.c_y];
            self.config.c_x_pre = row.width_index.items[row.getLen()];
        },
        .prev_page => {
            if (self.config.row_offset > self.config.screen_size.rows - 1) {
                self.config.row_offset -= self.config.screen_size.rows - 1;
            } else {
                self.config.row_offset = 0;
            }
        },
        .next_page => {
            self.config.row_offset += (self.config.screen_size.rows - 1);
            if (self.config.row_offset > self.getOffSetLimit()) {
                self.config.row_offset = self.getOffSetLimit();
            }
        },
    }
    self.normalizeCursor();
}

fn normalizeCursor(self: *Editor) void {
    if (self.config.c_y < self.getTopYOfScreen())
        self.config.c_y = self.getTopYOfScreen();
    if (self.config.c_y > self.getBottomYOfScreen())
        self.config.c_y = self.getBottomYOfScreen();
    const row = self.config.rows.items[self.config.c_y];
    if (row.getLen() <= 0)
        self.config.c_x = 0
    else if (self.config.c_x_pre > row.getWidth())
        self.config.c_x = row.getLen()
    else {
        for (row.width_index.items, 0..) |w, i| {
            if (self.config.c_x_pre <= w) {
                self.config.c_x = i;
                break;
            }
        }
    }
}

fn normalizeScrolling(self: *Editor) void {
    const half_of_screen: i64 = self.config.screen_size.rows / 2;
    if (self.config.c_y < self.getTopYOfScreen() or self.getBottomYOfScreen() <= self.config.c_y)
        self.scrollTo(@intCast(i64, self.config.c_y) - half_of_screen);
}

fn scrollTo(self: *Editor, y_offset: i64) void {
    if (y_offset < 0) {
        self.config.row_offset = 0;
        return;
    }
    if (y_offset + self.config.screen_size.rows > self.config.rows.items.len) {
        self.config.row_offset = self.config.rows.items.len - self.config.screen_size.rows;
        return;
    }
    self.config.row_offset = @intCast(usize, y_offset);
}

fn getTopYOfScreen(self: *const Editor) usize {
    return self.config.row_offset;
}

fn getBottomYOfScreen(self: *const Editor) usize {
    const offset = self.config.row_offset + self.config.screen_size.rows - 1;
    return if (offset < self.config.rows.items.len) offset else self.config.rows.items.len;
}

fn getOffSetLimit(self: *const Editor) usize {
    return if (self.config.rows.items.len > self.config.screen_size.rows)
        self.config.rows.items.len - self.config.screen_size.rows + 1
    else
        0;
}

fn refreshScreen(self: *const Editor, arena: mem.Allocator, buf: *std.ArrayList(u8)) !void {
    _ = arena;
    try buf.appendSlice("\x1b[?25l");
    try buf.appendSlice("\x1b[H");
    try self.drawRows(buf);
    try buf.appendSlice("\x1b[?25h");
}

fn deleteChar(self: *Editor) !void {
    var row = &self.config.rows.items[self.config.c_y];
    if (self.config.c_x >= row.getLen()) {
        if (self.config.c_y + 1 >= self.config.rows.items.len) {
            return;
        }
        var next_row = &self.config.rows.items[self.config.c_y + 1];
        try row.appendSlice(next_row.buffer.items);
        next_row.deinit();
        _ = self.config.rows.orderedRemove(self.config.c_y + 1);
        return;
    }
    _ = try row.remove(self.config.c_x);
}

fn deleteBackwardChar(self: *Editor) !void {
    if (!self.moveBackwardChar()) {
        return;
    }
    self.normalizeCursor();
    try self.deleteChar();
}

fn breakLine(self: *Editor) !void {
    var row = &self.config.rows.items[self.config.c_y];
    var next_row = try dew.UnicodeString.init(self.allocator);
    errdefer next_row.deinit();
    try next_row.appendSlice(row.buffer.items[row.u8_index.items[self.config.c_x]..]);
    try self.config.rows.insert(self.config.c_y + 1, next_row);
    for (0..row.getLen() - self.config.c_x) |_| {
        try row.remove(self.config.c_x);
    }
    self.moveForwardChar();
    self.normalizeCursor();
}

fn killLine(self: *Editor) !void {
    var row = &self.config.rows.items[self.config.c_y];
    if (self.config.c_x >= row.getLen()) {
        try self.deleteChar();
        return;
    }
    for (0..row.getLen() - self.config.c_x) |_| {
        try row.remove(self.config.c_x);
    }
}

fn moveBackwardChar(self: *Editor) bool {
    var moved = false;
    if (self.config.c_x > 0) {
        self.config.c_x_pre = self.config.rows.items[self.config.c_y].width_index.items[self.config.c_x - 1];
        moved = true;
    } else if (self.config.c_y > 0) {
        self.config.c_y -= 1;
        self.config.c_x_pre = self.config.rows.items[self.config.c_y].getWidth();
        moved = true;
    }
    self.normalizeScrolling();
    return moved;
}

fn moveForwardChar(self: *Editor) void {
    const row = self.config.rows.items[self.config.c_y];
    if (self.config.c_x < row.getLen()) {
        self.config.c_x_pre = row.width_index.items[self.config.c_x + 1];
    } else if (self.config.c_y < self.config.rows.items.len - 1) {
        self.config.c_y += 1;
        self.config.c_x_pre = 0;
    }
    self.normalizeScrolling();
}

fn moveToPreviousLine(self: *Editor) void {
    if (self.config.c_y > 0) {
        self.config.c_y -= 1;
        self.normalizeScrolling();
    }
}

fn moveToNextLine(self: *Editor) void {
    if (self.config.c_y < self.config.rows.items.len - 1) {
        self.config.c_y += 1;
        self.normalizeScrolling();
    }
}

fn clearScreen(_: *const Editor, _: mem.Allocator, buf: *std.ArrayList(u8)) !void {
    try buf.appendSlice("\x1b[2J");
    try buf.appendSlice("\x1b[H");
}

fn doRender(self: *const Editor, render: *const fn (self: *const Editor, arena: mem.Allocator, buf: *std.ArrayList(u8)) anyerror!void) !void {
    var arena = heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var buf = std.ArrayList(u8).init(self.allocator);
    defer buf.deinit();
    try render(self, arena.allocator(), &buf);
    try io.getStdOut().writeAll(buf.items);
}

fn enableRawMode() !os.termios {
    const orig = try os.tcgetattr(os.STDIN_FILENO);
    var term = orig;
    term.iflag &= ~(darwin_BRKINT | darwin_IXON | darwin_ICRNL | darwin_INPCK | darwin_ISTRIP);
    term.oflag &= ~darwin_OPOST;
    term.cflag |= darwin_CS8;
    term.lflag &= ~(darwin_ECHO | darwin_ICANON | darwin_IEXTEN | darwin_ISIG);
    try os.tcsetattr(os.STDIN_FILENO, os.TCSA.FLUSH, term);
    return orig;
}

fn disableRawMode(self: *const Editor) !void {
    try os.tcsetattr(os.STDIN_FILENO, os.TCSA.FLUSH, self.config.orig_termios);
}

fn drawRows(self: *const Editor, buf: *std.ArrayList(u8)) !void {
    var screen_y: usize = 0;
    var row_y = self.config.row_offset;
    var screen_c_x: usize = 0;
    var screen_c_y: usize = 0;
    while (screen_y < self.config.screen_size.rows) : (screen_y += 1) {
        if (screen_y > 0) try buf.appendSlice("\r\n");
        try buf.appendSlice("\x1b[K");
        if (row_y >= self.config.rows.items.len) {
            try buf.appendSlice("~");
        } else {
            const row = &self.config.rows.items[row_y];
            var width: usize = 0;
            for (0..row.getLen()) |i| {
                if (self.config.c_x == i and self.config.c_y == row_y) {
                    screen_c_x = width;
                    screen_c_y = screen_y;
                }
                const w = row.width_index.items[i + 1] - row.width_index.items[i];
                if (width + w > self.config.screen_size.cols) {
                    screen_y += 1;
                    if (screen_y >= self.config.screen_size.rows) {
                        break;
                    }
                    width = 0;
                    try buf.appendSlice("\r\n");
                    try buf.appendSlice("\x1b[K");
                }
                width += w;
                try buf.appendSlice(row.buffer.items[row.u8_index.items[i]..row.u8_index.items[i + 1]]);
            }
            if (self.config.c_x == row.getLen() and self.config.c_y == row_y) {
                screen_c_x = width;
                screen_c_y = screen_y;
            }
            row_y += 1;
        }
    }
    try buf.appendSlice("\r\n");
    try buf.appendSlice("\x1b[K");
    try buf.appendSlice(self.config.status_message);
    try buf.appendSlice("\x1b[H");
    var cursor = try fmt.allocPrint(self.allocator, "\x1b[{d};{d}H", .{ screen_c_y + 1, screen_c_x + 1 });
    defer self.allocator.free(cursor);
    try buf.appendSlice(cursor);
}

const WindowSize = struct {
    rows: u32,
    cols: u32,
};

fn getWindowSize() !WindowSize {
    var ws: c.winsize = undefined;
    const status = c.ioctl(io.getStdOut().handle, c.TIOCGWINSZ, &ws);
    if (status != 0) {
        return error.UnknownWinsize;
    }
    return WindowSize{
        .rows = ws.ws_row - 1, // status bar uses the last line
        .cols = ws.ws_col,
    };
}

fn insertChar(self: *Editor, char: u21) !void {
    var row = &self.config.rows.items[self.config.c_y];
    try row.insert(self.config.c_x, char);
    self.moveCursor(.right);
}

test "getWindowSize" {
    const size = try getWindowSize();
    try testing.expect(size.rows > 0);
    try testing.expect(size.cols > 0);
}
