const Selections = @This();
const std = @import("std");
const Editor = @import("../Editor.zig");
const parser = @import("../parser.zig");
const Module = @import("../Module.zig");
const Keyboard = @import("../Keyboard.zig");
const ModuleDefinition = @import("../ModuleDefinition.zig");
const Command = @import("../Command.zig");
const Position = @import("../Position.zig");

editor: *Editor,
definition: ModuleDefinition,

pub fn init(editor: *Editor) !*Selections {
    const selections = try editor.allocator.create(Selections);
    errdefer editor.allocator.destroy(selections);
    selections.* = .{
        .editor = editor,
        .definition = ModuleDefinition.parse(editor.allocator, @embedFile("selections.yaml")) catch unreachable,
    };
    return selections;
}

pub fn module(self: *Selections) Module {
    return .{
        .ptr = self,
        .vtable = &.{
            .runCommand = runCommand,
            .deinit = deinit,
        },
        .definition = &self.definition,
    };
}

fn deinit(ctx: *anyopaque) void {
    var self: *Selections = @ptrCast(@alignCast(ctx));
    self.definition.deinit();
    self.editor.allocator.destroy(self);
}

fn runCommand(ctx: *anyopaque, command: *const Command, _: std.io.AnyReader, _: std.io.AnyWriter) anyerror!void {
    var self: *Selections = @ptrCast(@alignCast(ctx));
    if (std.mem.eql(u8, command.subcommand.?.name, "get")) {
        return;
    }
    if (std.mem.eql(u8, command.subcommand.?.name, "move")) {
        var state: parser.State = .{
            .allocator = self.editor.allocator,
            .input = command.subcommand.?.positionals[0].str,
        };
        const position = try parsePosition(&state);
        try self.editor.client.active_ref.?.selection.setPosition(position);
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
