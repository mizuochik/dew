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
        if (buf[0] == 'q') {
            break;
        } else if (ascii.isControl(c)) {
            std.debug.print("{d}\n", .{c});
        } else {
            std.debug.print("{d} ({c})\n", .{ c, c });
        }
    } else |err| {
        return err;
    }
}

const darwin_icanon = 0x100;

fn enableRawMode() !os.termios {
    const orig = try os.tcgetattr(os.STDIN_FILENO);
    var term = orig;
    term.lflag &= ~(os.linux.ECHO | darwin_icanon);
    try os.tcsetattr(os.STDIN_FILENO, os.TCSA.FLUSH, term);
    return orig;
}

fn disableRawMode(orig: os.termios) !void {
    try os.tcsetattr(os.STDIN_FILENO, os.TCSA.FLUSH, orig);
}
