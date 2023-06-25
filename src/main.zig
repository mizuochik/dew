const std = @import("std");
const os = std.os;
const io = std.io;
const ascii = std.ascii;
const mem = std.mem;
const heap = std.heap;
const debug = std.debug;
const testing = std.testing;
const c = @import("c.zig");

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const orig = try enableRawMode();
    defer disableRawMode(orig) catch unreachable;
    defer doRender(allocator, clearScreen) catch unreachable;

    while (true) {
        try doRender(allocator, refreshScreen);
        processKeypress(try readKey()) catch |err| switch (err) {
            error.Quit => return,
            else => return err,
        };
    }
}

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

fn refreshScreen(buf: *std.ArrayList(u8)) !void {
    try buf.appendSlice("\x1b[?25l");
    try buf.appendSlice("\x1b[2J");
    try buf.appendSlice("\x1b[H");
    try drawRows(buf);
    try buf.appendSlice("\x1b[H");
    try buf.appendSlice("\x1b[?25h");
}

fn clearScreen(buf: *std.ArrayList(u8)) !void {
    try buf.appendSlice("\x1b[2J");
    try buf.appendSlice("\x1b[H");
}

fn doRender(allocator: mem.Allocator, render: *const fn (buf: *std.ArrayList(u8)) anyerror!void) !void {
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();
    try render(&buf);
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

fn disableRawMode(orig: os.termios) !void {
    try os.tcsetattr(os.STDIN_FILENO, os.TCSA.FLUSH, orig);
}

fn drawRows(buf: *std.ArrayList(u8)) !void {
    for (0..24) |_| {
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
