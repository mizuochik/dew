const std = @import("std");
const os = std.os;
const io = std.io;
const ascii = std.ascii;

pub fn main() !void {
    const orig = try enableRawMode();
    defer disableRawMode(orig) catch unreachable;
    defer refreshScreen() catch unreachable;

    while (true) {
        try refreshScreen();
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

fn refreshScreen() !void {
    _ = try io.getStdOut().write("\x1b[2J");
    _ = try io.getStdOut().write("\x1b[H");
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