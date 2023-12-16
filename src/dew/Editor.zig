const std = @import("std");
const dew = @import("../dew.zig");

const Editor = @This();

allocator: std.mem.Allocator,
controller: *dew.controllers.EditorController,
keyboard: *dew.Keyboard,
terminal: *dew.Terminal,

pub fn init(allocator: std.mem.Allocator, controller: *dew.controllers.EditorController) !Editor {
    const keyboard = try allocator.create(dew.Keyboard);
    errdefer allocator.destroy(keyboard);
    keyboard.* = dew.Keyboard{};

    const terminal = try allocator.create(dew.Terminal);
    errdefer allocator.destroy(terminal);
    terminal.* = .{};

    return Editor{
        .allocator = allocator,
        .controller = controller,
        .keyboard = keyboard,
        .terminal = terminal,
    };
}

pub fn deinit(self: *const Editor) void {
    self.allocator.destroy(self.keyboard);
    self.allocator.destroy(self.terminal);
}
