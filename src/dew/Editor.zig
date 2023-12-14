const std = @import("std");
const dew = @import("../dew.zig");

const Editor = @This();

allocator: std.mem.Allocator,
editor_controller: *dew.controllers.EditorController,
keyboard: dew.Keyboard,
terminal: dew.Terminal,

pub fn init(allocator: std.mem.Allocator, editor_controller: *dew.controllers.EditorController) Editor {
    return Editor{
        .allocator = allocator,
        .editor_controller = editor_controller,
        .keyboard = dew.Keyboard{},
        .terminal = .{},
    };
}
