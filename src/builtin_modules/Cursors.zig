const std = @import("std");
const Editor = @import("../Editor.zig");
const parser = @import("../parser.zig");
const Module = @import("../Module.zig");
const Keyboard = @import("../Keyboard.zig");
const ModuleDefinition = @import("../ModuleDefinition.zig");
const Command = @import("../Command.zig");
const Position = @import("../Position.zig");

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
            .runCommand = runCommand,
            .deinit = deinit,
        },
        .definition = ModuleDefinition.parse(self.editor.allocator, @embedFile("cursors.yaml")) catch unreachable,
    };
}

fn deinit(_: *anyopaque) void {}

fn runCommand(ctx: *anyopaque, command: *const Command, _: std.io.AnyReader, _: std.io.AnyWriter) anyerror!void {
    var self: *@This() = @ptrCast(@alignCast(ctx));
    if (std.mem.eql(u8, command.subcommand.?.name, "get")) {
        return;
    }
    if (std.mem.eql(u8, command.subcommand.?.name, "move")) {
        var state: parser.State = .{
            .allocator = self.editor.allocator,
            .input = command.subcommand.?.positionals[0].str,
        };
        const position = try parsePosition(&state);
        try self.editor.client.active_ref.?.cursor.setPosition(position);
        return;
    }
    unreachable;
}

fn parsePosition(state: *parser.State) !Position {
    const line = try parser.number(state);
    _ = try parser.character(state, ':');
    const character = try parser.number(state);
    return .{
        .x = @intCast(@max(0, character - 1)),
        .y = @intCast(@max(0, line - 1)),
    };
}
