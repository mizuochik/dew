const std = @import("std");
const os = std.os;
const io = std.io;
const ascii = std.ascii;
const mem = std.mem;
const heap = std.heap;
const debug = std.debug;
const fmt = std.fmt;
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
    orig_termios: ?os.termios = null,
    c_x: i32 = 0,
    c_y: i32 = 0,
};

allocator: mem.Allocator,
config: Config = Config{},

pub fn run(self: *Editor) !void {
    try self.enableRawMode();
    defer self.disableRawMode() catch unreachable;
    defer self.doRender(clearScreen) catch unreachable;

    while (true) {
        try self.doRender(refreshScreen);
        processKeypress(try readKey()) catch |err| switch (err) {
            error.Quit => return,
            else => return err,
        };
    }
}

fn isCtrlKey(comptime key: u8) u8 {
    return key & 0x1f;
}

fn readKey() !u8 {
    var buf = [_]u8{0} ** 32;
    _ = try io.getStdIn().read(&buf);
    return buf[0];
}

fn processKeypress(key: u8) !void {
    if (key == isCtrlKey('x')) {
        return error.Quit;
    } else if (ascii.isControl(key)) {
        std.debug.print("{d}\r\n", .{key});
    } else {
        std.debug.print("{d} ({c})\r\n", .{ key, key });
    }
}

fn refreshScreen(self: *const Editor, arena: mem.Allocator, buf: *std.ArrayList(u8)) !void {
    try buf.appendSlice("\x1b[?25l");
    try buf.appendSlice("\x1b[H");
    try drawRows(buf);
    try buf.appendSlice(try fmt.allocPrint(arena, "\x1b[{d};{d}H", .{ self.config.c_y + 1, self.config.c_x + 1 }));
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

fn enableRawMode(self: *Editor) !void {
    const orig = try os.tcgetattr(os.STDIN_FILENO);
    self.config.orig_termios = orig;
    var term = orig;
    term.iflag &= ~(darwin_BRKINT | darwin_IXON | darwin_ICRNL | darwin_INPCK | darwin_ISTRIP);
    term.oflag &= ~darwin_OPOST;
    term.cflag |= darwin_CS8;
    term.lflag &= ~(darwin_ECHO | darwin_ICANON | darwin_IEXTEN | darwin_ISIG);
    try os.tcsetattr(os.STDIN_FILENO, os.TCSA.FLUSH, term);
}

fn disableRawMode(self: *const Editor) !void {
    const orig = self.config.orig_termios orelse return;
    try os.tcsetattr(os.STDIN_FILENO, os.TCSA.FLUSH, orig);
}

fn drawRows(buf: *std.ArrayList(u8)) !void {
    for (0..24) |_| {
        try buf.appendSlice("\x1b[K");
        try buf.appendSlice("~\r\n");
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
