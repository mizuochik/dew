const std = @import("std");
const os = std.os;
const io = std.io;
const ascii = std.ascii;
const mem = std.mem;
const heap = std.heap;
const debug = std.debug;
const fmt = std.fmt;
const fs = std.fs;
const testing = std.testing;
const c = @import("c.zig");

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

const Editor = @This();

const Config = struct {
    orig_termios: os.termios,
    screen_size: WindowSize,
    c_x: usize = 0,
    c_y: usize = 0,
    row_offset: usize = 0,
    rows: std.ArrayList(std.ArrayList(u8)),
};

const Key = union(enum) {
    plain: u8,
    control: u8,
    arrow: Arrow,
};

const Arrow = enum {
    up,
    down,
    right,
    left,
    next_page,
    prev_page,
};

allocator: mem.Allocator,
config: Config,

pub fn init(allocator: mem.Allocator) !Editor {
    const orig = try enableRawMode();
    const size = try getWindowSize();

    return Editor{
        .allocator = allocator,
        .config = Config{
            .orig_termios = orig,
            .screen_size = size,
            .rows = std.ArrayList(std.ArrayList(u8)).init(allocator),
        },
    };
}

pub fn deinit(self: *const Editor) !void {
    try self.disableRawMode();
    try self.doRender(clearScreen);
    for (self.config.rows.items) |row| row.deinit();
    self.config.rows.deinit();
}

pub fn openFile(self: *Editor, path: []const u8) !void {
    var f = try fs.cwd().openFile(path, .{});
    var reader = f.reader();

    var new_rows = std.ArrayList(std.ArrayList(u8)).init(self.allocator);
    errdefer new_rows.deinit();
    while (true) {
        var new_row = std.ArrayList(u8).init(self.allocator);
        errdefer new_row.deinit();
        reader.streamUntilDelimiter(new_row.writer(), '\n', null) catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };
        try new_rows.append(new_row);
    }

    for (self.config.rows.items) |row| row.deinit();
    self.config.rows.deinit();
    self.config.rows = new_rows;
}

pub fn run(self: *Editor) !void {
    try self.doRender(clearScreen);
    while (true) {
        try self.doRender(refreshScreen);
        self.processKeypress(try readKey()) catch |err| switch (err) {
            error.Quit => return,
            else => return err,
        };
    }
}

fn ctrlKey(comptime key: u8) u8 {
    return key & 0x1f;
}

fn readKey() !Key {
    const k = try io.getStdIn().reader().readByte();
    if (k == 0x1b) {
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
    }
    if (ascii.isControl(k)) {
        return switch (k) {
            ctrlKey('p') => .{ .arrow = .up },
            ctrlKey('n') => .{ .arrow = .down },
            ctrlKey('f') => .{ .arrow = .right },
            ctrlKey('b') => .{ .arrow = .left },
            ctrlKey('y') => .{ .arrow = .prev_page },
            ctrlKey('v') => .{ .arrow = .next_page },
            else => .{ .control = k },
        };
    }
    return .{ .plain = k };
}

fn processKeypress(self: *Editor, key: Key) !void {
    switch (key) {
        .control => |k| if (k == ctrlKey('x')) {
            return error.Quit;
        } else {},
        .plain => |_| {},
        .arrow => |k| self.moveCursor(k),
    }
}

fn moveCursor(self: *Editor, k: Arrow) void {
    switch (k) {
        .up => if (self.config.c_y > 0) {
            self.config.c_y -= 1;
        },
        .down => if (self.config.c_y < self.config.rows.items.len - 1) {
            self.config.c_y += 1;
        },
        .left => if (self.config.c_x > 0) {
            self.config.c_x -= 1;
        },
        .right => if (self.config.c_x < self.config.rows.items[self.config.c_y].items.len) {
            self.config.c_x += 1;
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
            if (self.config.row_offset > self.get_offset_limit()) {
                self.config.row_offset = self.get_offset_limit();
            }
        },
    }
    self.normalizeCursor();
}

fn normalizeCursor(self: *Editor) void {
    if (self.config.c_y < self.get_top_y_of_screen())
        self.config.c_y = self.get_top_y_of_screen();
    if (self.config.c_y >= self.get_bottom_y_of_screen() - 1)
        self.config.c_y = self.get_bottom_y_of_screen() - 1;
}

fn get_top_y_of_screen(self: *const Editor) usize {
    return self.config.row_offset;
}

fn get_bottom_y_of_screen(self: *const Editor) usize {
    const offset = self.config.row_offset + self.config.screen_size.rows;
    return if (offset < self.config.rows.items.len) offset else self.config.rows.items.len;
}

fn get_offset_limit(self: *const Editor) usize {
    return if (self.config.rows.items.len > self.config.screen_size.rows)
        self.config.rows.items.len - self.config.screen_size.rows + 1
    else
        0;
}

fn refreshScreen(self: *const Editor, arena: mem.Allocator, buf: *std.ArrayList(u8)) !void {
    try buf.appendSlice("\x1b[?25l");
    try buf.appendSlice("\x1b[H");
    try self.drawRows(buf);
    try buf.appendSlice(try fmt.allocPrint(arena, "\x1b[{d};{d}H", .{ self.config.c_y - self.config.row_offset + 1, self.config.c_x + 1 }));
    try buf.appendSlice("\x1b[?25h");
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
    for (0..self.config.screen_size.rows - 1) |i| {
        const j = i + self.config.row_offset;
        try buf.appendSlice("\x1b[K");
        try buf.appendSlice(if (j >= self.config.rows.items.len) "~" else self.config.rows.items[j].items);
        try buf.appendSlice("\r\n");
    }
    try buf.appendSlice("\x1b[H");
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
        .rows = ws.ws_row,
        .cols = ws.ws_col,
    };
}

test "getWindowSize" {
    const size = try getWindowSize();
    try testing.expect(size.rows > 0);
    try testing.expect(size.cols > 0);
}
