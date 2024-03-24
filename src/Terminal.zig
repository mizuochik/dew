const Terminal = @This();
const std = @import("std");
const buildtin = @import("builtin");
const c = @import("c.zig");

orig_termios: ?std.os.termios = null,

pub fn enableRawMode(self: *Terminal) !void {
    const orig = try std.posix.tcgetattr(std.os.STDIN_FILENO);
    var term = orig;
    term.iflag.BRKINT = false;
    term.iflag.IXON = false;
    term.iflag.ICRNL = false;
    term.iflag.INPCK = false;
    term.iflag.ISTRIP = false;
    term.oflag.OPOST = false;
    term.cflag.CSIZE = .CS8;
    term.lflag.ECHO = false;
    term.lflag.ICANON = false;
    term.lflag.IEXTEN = false;
    term.lflag.ISIG = false;
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
    switch (buildtin.os.tag) {
        .linux => {
            var ws: std.os.linux.winsize = undefined;
            const fd: usize = std.os.STDIN_FILENO;
            const rc = std.os.linux.syscall3(.ioctl, fd, std.os.linux.T.IOCGWINSZ, @intFromPtr(&ws));
            switch (std.os.linux.getErrno(rc)) {
                else => |no| std.debug.print("result = {}\n", .{no}),
            }
            return WindowSize{
                .rows = ws.ws_row,
                .cols = ws.ws_col,
            };
        },
        else => {
            var ws: c.winsize = undefined;
            const status = c.ioctl(std.io.getStdOut().handle, c.TIOCGWINSZ, &ws);
            if (status != 0) {
                return error.UnknownWinsize;
            }
            return WindowSize{
                .rows = ws.ws_row,
                .cols = ws.ws_col,
            };
        },
    }
}
