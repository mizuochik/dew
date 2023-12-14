const std = @import("std");
const dew = @import("../dew.zig");

const ControlKeys = enum(u8) {
    DEL = 127,
    RETURN = 0x0d,
};

const Editor = @This();

const Config = struct {
    orig_termios: ?std.os.termios,
};

allocator: std.mem.Allocator,
config: Config,
editor_controller: *dew.controllers.EditorController,
keyboard: dew.Keyboard,
terminal: dew.Terminal,

pub fn init(allocator: std.mem.Allocator, editor_controller: *dew.controllers.EditorController) Editor {
    return Editor{
        .allocator = allocator,
        .config = Config{
            .orig_termios = null,
        },
        .editor_controller = editor_controller,
        .keyboard = dew.Keyboard{},
        .terminal = .{},
    };
}

pub fn run(self: *Editor) !void {
    while (true) {
        const key = try self.keyboard.inputKey();
        self.editor_controller.processKeypress(key) catch |err| switch (err) {
            error.Quit => return,
            else => return err,
        };
    }
}

pub const WindowSize = struct {
    rows: u32,
    cols: u32,
};

pub fn getWindowSize(_: *const Editor) !WindowSize {
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
