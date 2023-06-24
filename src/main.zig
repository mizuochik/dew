const std = @import("std");
const os = std.os;
const io = std.io;
const ascii = std.ascii;

pub fn main() !void {
    const orig = try enableRawMode();
    defer disableRawMode(orig) catch unreachable;

    var buf = [_]u8{0} ** 32;
    while (io.getStdIn().read(&buf)) |_| {
        const c = buf[0];
        if (buf[0] == isCtrlKey('x')) {
            break;
        } else if (ascii.isControl(c)) {
            std.debug.print("{d}\r\n", .{c});
        } else {
            std.debug.print("{d} ({c})\r\n", .{ c, c });
        }
    } else |err| {
        return err;
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
