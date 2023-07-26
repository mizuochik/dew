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
last_view_x: usize = 0,
buffer: *dew.Buffer,
buffer_view: *dew.BufferView,

pub fn init(allocator: mem.Allocator) !Editor {
    const orig = try enableRawMode();
    const size = try getWindowSize();
    const status = try fmt.allocPrint(allocator, "Initialized", .{});
    errdefer allocator.free(status);

    const buffer = try allocator.create(dew.Buffer);
    errdefer allocator.destroy(buffer);
    buffer.* = dew.Buffer.init(allocator);
    errdefer buffer.deinit();

    const buffer_view = try allocator.create(dew.BufferView);
    errdefer allocator.destroy(buffer_view);
    buffer_view.* = try dew.BufferView.init(allocator, buffer, size.cols, size.rows - 1);
    errdefer buffer_view.deinit();

    try buffer.bindView(buffer_view.asView());

    return Editor{
        .allocator = allocator,
        .config = Config{
            .orig_termios = orig,
            .screen_size = size,
            .rows = std.ArrayList(dew.UnicodeString).init(allocator),
            .status_message = status,
        },
        .buffer = buffer,
        .buffer_view = buffer_view,
    };
}

pub fn deinit(self: *const Editor) !void {
    try self.disableRawMode();
    try self.doRender(clearScreen);
    self.allocator.free(self.config.status_message);
    self.buffer.deinit();
    self.allocator.destroy(self.buffer);
    self.buffer_view.deinit();
    self.allocator.destroy(self.buffer_view);
}

pub fn openFile(self: *Editor, path: []const u8) !void {
    var f = try fs.cwd().openFile(path, .{});
    var reader = f.reader();

    var new_rows = std.ArrayList(dew.UnicodeString).init(self.allocator);
    errdefer {
        for (new_rows.items) |row| row.deinit();
        new_rows.deinit();
    }

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
    }

    var last_row = try dew.UnicodeString.init(self.allocator);
    errdefer last_row.deinit();
    try new_rows.append(last_row);

    for (self.buffer.rows.items) |row| row.deinit();
    self.buffer.rows.deinit();
    self.buffer.rows = new_rows;
    try self.buffer.updateViews();

    self.config.rows.deinit();
    self.config.rows = new_rows;
    self.config.file_path = path;
}

pub fn saveFile(self: *Editor) !void {
    var f = try fs.cwd().createFile(self.config.file_path.?, .{});
    defer f.close();
    for (self.buffer.rows.items, 0..) |row, i| {
        if (i > 0)
            _ = try f.write("\n");
        _ = try f.write(row.buffer.items);
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

fn updateLastViewX(self: *Editor) void {
    self.last_view_x = self.buffer_view.getCursor().x;
}

fn ctrlKey(comptime key: u8) u8 {
    return key & 0x1f;
}

fn readKey() !Key {
    var h = try io.getStdIn().reader().readByte();
    if (h == 0x1b) {
        h = try io.getStdIn().reader().readByte();
        if (h == '[') {
            h = try io.getStdIn().reader().readByte();
            switch (h) {
                'A' => return .{ .arrow = .up },
                'B' => return .{ .arrow = .down },
                'C' => return .{ .arrow = .right },
                'D' => return .{ .arrow = .left },
                else => {},
            }
        }
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
        .up => {
            const y = self.buffer_view.getCursor().y;
            if (y > 0) {
                const new_cursor = self.buffer_view.getBufferPopsition(.{ .x = self.last_view_x, .y = y - 1 });
                self.buffer.setCursor(new_cursor.x, new_cursor.y);
            }
        },
        .down => {
            const y = self.buffer_view.getCursor().y;
            if (y < self.buffer_view.rows.items.len - 1) {
                const new_cursor = self.buffer_view.getBufferPopsition(.{ .x = self.last_view_x, .y = y + 1 });
                self.buffer.setCursor(new_cursor.x, new_cursor.y);
            }
        },
        .left => {
            self.buffer.moveBackward();
            self.updateLastViewX();
        },
        .right => {
            self.buffer.moveForward();
            self.updateLastViewX();
        },
        .begin_of_line => {
            self.buffer.moveToBeginningOfLine();
            self.updateLastViewX();
        },
        .end_of_line => {
            self.buffer.moveToEndOfLine();
            self.updateLastViewX();
        },
        .prev_page => self.buffer_view.scrollUp(self.buffer_view.height / 2),
        .next_page => self.buffer_view.scrollDown(self.buffer_view.height / 2),
    }
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
    try self.buffer.updateViews();
    try buf.appendSlice("\x1b[?25l");
    try buf.appendSlice("\x1b[H");
    try self.drawRows(buf);
    const cursor = self.buffer_view.getCursor();
    try buf.appendSlice(try fmt.allocPrint(arena, "\x1b[{d};{d}H", .{ cursor.y + self.buffer_view.y_scroll + 1, cursor.x + 1 }));
    try buf.appendSlice("\x1b[?25h");
}

fn deleteChar(self: *Editor) !void {
    try self.buffer.deleteChar();
    self.updateLastViewX();
}

fn deleteBackwardChar(self: *Editor) !void {
    try self.buffer.deleteBackwardChar();
    self.updateLastViewX();
}

fn breakLine(self: *Editor) !void {
    try self.buffer.breakLine();
    self.updateLastViewX();
}

fn killLine(self: *Editor) !void {
    try self.buffer.killLine();
    self.updateLastViewX();
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
    for (0..self.buffer_view.height) |y| {
        if (y > 0) try buf.appendSlice("\r\n");
        try buf.appendSlice("\x1b[K");
        try buf.appendSlice(self.buffer_view.getRowView(y + self.buffer_view.y_scroll));
    }
    try buf.appendSlice("\r\n");
    try buf.appendSlice("\x1b[K");
    try buf.appendSlice(self.config.status_message);
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
    try self.buffer.insertChar(char);
    self.updateLastViewX();
}

test "getWindowSize" {
    const size = try getWindowSize();
    try testing.expect(size.rows > 0);
    try testing.expect(size.cols > 0);
}
