const std = @import("std");
const dew = @import("../dew.zig");

const darwin_ECHO: std.os.tcflag_t = 0x8;
const darwin_ICANON: std.os.tcflag_t = 0x100;
const darwin_ISIG: std.os.tcflag_t = 0x80;
const darwin_IXON: std.os.tcflag_t = 0x200;
const darwin_IEXTEN: std.os.tcflag_t = 0x400;
const darwin_ICRNL: std.os.tcflag_t = 0x100;
const darwin_OPOST: std.os.tcflag_t = 0x1;
const darwin_BRKINT: std.os.tcflag_t = 0x2;
const darwin_INPCK: std.os.tcflag_t = 0x10;
const darwin_ISTRIP: std.os.tcflag_t = 0x20;
const darwin_CS8: std.os.tcflag_t = 0x300;

const Terminal = @This();

orig_termios: ?std.os.termios = null,

pub fn enableRawMode(self: *Terminal) !void {
    const orig = try std.os.tcgetattr(std.os.STDIN_FILENO);
    var term = orig;
    term.iflag &= ~(darwin_BRKINT | darwin_IXON | darwin_ICRNL | darwin_INPCK | darwin_ISTRIP);
    term.oflag &= ~darwin_OPOST;
    term.cflag |= darwin_CS8;
    term.lflag &= ~(darwin_ECHO | darwin_ICANON | darwin_IEXTEN | darwin_ISIG);
    try std.os.tcsetattr(std.os.STDIN_FILENO, std.os.TCSA.FLUSH, term);
    self.orig_termios = orig;
}

pub fn disableRawMode(self: *Terminal) !void {
    if (self.orig_termios) |orig| {
        try std.os.tcsetattr(std.os.STDIN_FILENO, std.os.TCSA.FLUSH, orig);
    }
}

pub const WindowSize = struct {
    rows: u32,
    cols: u32,
};

pub fn getWindowSize(_: *const Terminal) !WindowSize {
    var ws: dew.c.winsize = undefined;
    const status = dew.c.ioctl(std.io.getStdOut().handle, dew.c.TIOCGWINSZ, &ws);
    if (status != 0) {
        return error.UnknownWinsize;
    }
    return WindowSize{
        .rows = ws.ws_row,
        .cols = ws.ws_col,
    };
}
