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
