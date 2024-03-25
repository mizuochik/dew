const std = @import("std");
const Module = @import("../Module.zig");
const ModuleDefinition = @import("../ModuleDefinition.zig");
const Editor = @import("../Editor.zig");
const Command = @import("../Command.zig");

const CommandLine = @This();

editor: *Editor,
definiton: ModuleDefinition,

pub fn init(editor: *Editor) !*CommandLine {
    const self = try editor.allocator.create(CommandLine);
    errdefer editor.allocator.destroy(self);
    self.* = .{
        .editor = editor,
        .definiton = ModuleDefinition.parse(editor.allocator, @embedFile("CommandLine.yaml")) catch unreachable,
    };
    return self;
}

pub fn module(self: *CommandLine) Module {
    return .{
        .ptr = self,
        .definition = &self.definiton,
        .vtable = &.{
            .deinit = deinit,
            .runCommand = runCommand,
        },
    };
}

fn deinit(ptr: *anyopaque) void {
    var self: *CommandLine = @ptrCast(@alignCast(ptr));
    self.definiton.deinit();
    self.editor.allocator.destroy(self);
}

fn runCommand(ptr: *anyopaque, command: *const Command, _: std.io.AnyReader, _: std.io.AnyWriter) anyerror!void {
    var self: *CommandLine = @ptrCast(@alignCast(ptr));
    if (std.mem.eql(u8, command.subcommand.?.name, "toggle")) {
        try self.editor.client.toggleCommandLine();
        return;
    }
    if (std.mem.eql(u8, command.subcommand.?.name, "put")) {
        if (!self.editor.client.isCommandLineActive())
            try self.editor.client.toggleCommandLine();
        try self.editor.client.command_line.clear();
        try self.editor.client.command_line.rows.items[0].appendSlice(command.subcommand.?.positionals[0].str);
        return;
    }
    unreachable;
}
