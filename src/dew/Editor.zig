const std = @import("std");
const dew = @import("../dew.zig");

const Editor = @This();

allocator: std.mem.Allocator,
controller: *dew.controllers.EditorController,
keyboard: dew.Keyboard,
terminal: dew.Terminal,

pub fn init(allocator: std.mem.Allocator, controller: *dew.controllers.EditorController) Editor {
    return Editor{
        .allocator = allocator,
        .controller = controller,
        .keyboard = dew.Keyboard{},
        .terminal = .{},
    };
}
