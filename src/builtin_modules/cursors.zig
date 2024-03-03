const std = @import("std");
const Editor = @import("../Editor.zig");
const Module = @import("../Module.zig");
const Keyboard = @import("../Keyboard.zig");
const ModuleDefinition = @import("../ModuleDefinition.zig");

editor: *Editor,

pub fn init(editor: *Editor) @This() {
    return .{
        .editor = editor,
    };
}

pub fn module(self: *@This()) Module {
    return .{
        .ptr = self,
        .vtable = &.{
            .apiCommand = command,
            .deinit = deinit,
        },
        .definition = ModuleDefinition.parse(self.editor.allocator, @embedFile("cursors.yaml")) catch unreachable,
    };
}

fn deinit(_: *anyopaque) void {}

fn command(_: *anyopaque, arguments: [][]const u8, _: std.io.AnyReader, _: std.io.AnyWriter) anyerror!void {
    if (std.mem.eql(u8, arguments[0], "move-to")) {}
    return Module.Error.InvalidCommand;
}
