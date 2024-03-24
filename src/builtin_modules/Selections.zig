const Selections = @This();
const std = @import("std");
const Editor = @import("../Editor.zig");
const parser = @import("../parser.zig");
const Module = @import("../Module.zig");
const Keyboard = @import("../Keyboard.zig");
const ModuleDefinition = @import("../ModuleDefinition.zig");
const Command = @import("../Command.zig");
const Position = @import("../Position.zig");
const TextView = @import("../TextView.zig");

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

    var edit = if (command.options.get("file").?.bool)
        self.editor.client.getActiveFile().?
    else if (command.options.get("command").?.bool)
        &self.editor.client.command_line_ref
    else
        self.editor.client.getActiveEdit().?;

    const view = self.getCurrentView();
    const view_y = view.getSelection(edit).line;

    if (std.mem.eql(u8, command.subcommand.?.name, "list"))
        return;
    if (std.mem.eql(u8, command.subcommand.?.name, "get"))
        return;
    if (std.mem.eql(u8, command.subcommand.?.name, "move")) {
        const position = b: {
            var state: parser.State = .{
                .allocator = self.editor.allocator,
                .input = command.subcommand.?.positionals[0].str,
            };
            break :b try parsePosition(&state);
        };
        try edit.selection.setPosition(position);
        return;
    }
    if (std.mem.eql(u8, command.subcommand.?.name, "forward-character")) {
        try edit.selection.moveForward();
        self.getCurrentView().updateLastSelectionX(edit);
        return;
    }
    if (std.mem.eql(u8, command.subcommand.?.name, "backward-character")) {
        try edit.selection.moveBackward();
        self.getCurrentView().updateLastSelectionX(edit);
        return;
    }
    if (std.mem.eql(u8, command.subcommand.?.name, "next-line")) {
        if (view_y >= view.getNumberOfLines() - 1) {
            return;
        }
        const pos = view.getBufferPosition(edit, .{ .character = edit.selection.last_view_x, .line = view_y + 1 });
        try edit.selection.setPosition(pos);
        return;
    }
    if (std.mem.eql(u8, command.subcommand.?.name, "previous-line")) {
        if (view_y <= 0) {
            return;
        }
        const pos = view.getBufferPosition(edit, .{ .character = edit.selection.last_view_x, .line = view_y - 1 });
        try edit.selection.setPosition(pos);
        return;
    }
    if (std.mem.eql(u8, command.subcommand.?.name, "beginning-of-line")) {
        try edit.selection.moveToBeginningOfLine();
        return;
    }
    if (std.mem.eql(u8, command.subcommand.?.name, "end-of-line")) {
        try edit.selection.moveToEndOfLine();
        return;
    }
    unreachable;
}

fn parsePosition(state: *parser.State) !Position {
    const line = try parser.number(state);
    _ = try parser.character(state, ':');
    const character = try parser.number(state);
    return .{
        .character = @intCast(@max(0, character - 1)),
        .line = @intCast(@max(0, line - 1)),
    };
}

fn getCurrentView(self: *Selections) *TextView {
    return if (self.editor.client.isCommandLineActive())
        &self.editor.command_ref_view
    else
        &self.editor.edit_view;
}
