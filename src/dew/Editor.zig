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
const Buffer = dew.models.Buffer;
const Key = dew.models.Key;
const Arrow = dew.models.Arrow;
const UnicodeString = dew.models.UnicodeString;
const c = dew.c;
const EditorController = dew.controllers.EditorController;

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
    orig_termios: ?os.termios,
};

allocator: mem.Allocator,
config: Config,
buffer_controller: *EditorController,
keyboard: dew.Keyboard,

pub fn init(allocator: mem.Allocator, buffer_controller: *EditorController) Editor {
    return Editor{
        .allocator = allocator,
        .config = Config{
            .orig_termios = null,
        },
        .buffer_controller = buffer_controller,
        .keyboard = dew.Keyboard{},
    };
}

pub fn run(self: *Editor) !void {
    while (true) {
        const key = try self.keyboard.inputKey();
        self.buffer_controller.processKeypress(key) catch |err| switch (err) {
            error.Quit => return,
            else => return err,
        };
    }
}

pub fn enableRawMode(self: *Editor) !void {
    const orig = try os.tcgetattr(os.STDIN_FILENO);
    var term = orig;
    term.iflag &= ~(darwin_BRKINT | darwin_IXON | darwin_ICRNL | darwin_INPCK | darwin_ISTRIP);
    term.oflag &= ~darwin_OPOST;
    term.cflag |= darwin_CS8;
    term.lflag &= ~(darwin_ECHO | darwin_ICANON | darwin_IEXTEN | darwin_ISIG);
    try os.tcsetattr(os.STDIN_FILENO, os.TCSA.FLUSH, term);
    self.config.orig_termios = orig;
}

pub fn disableRawMode(self: *const Editor) !void {
    if (self.config.orig_termios) |orig| {
        try os.tcsetattr(os.STDIN_FILENO, os.TCSA.FLUSH, orig);
    }
}

const WindowSize = struct {
    rows: u32,
    cols: u32,
};

pub fn getWindowSize(_: *const Editor) !WindowSize {
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
