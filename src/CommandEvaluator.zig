const CommandEvaluator = @This();
const CommandParser = @import("CommandParser.zig");
const CommandParser3 = @import("CommandParser3.zig");
const CommandLine = @import("CommandLine.zig");
const Command = @import("Command.zig");
const Editor = @import("Editor.zig");
const UnicodeString = @import("UnicodeString.zig");
const std = @import("std");
const Module = @import("Module.zig");
const ModuleDefinition = @import("ModuleDefinition.zig");
const Resource = @import("Resource.zig");

editor: *Editor,

pub fn evaluate(self: *CommandEvaluator, raw_command_line: UnicodeString) !void {
    var parser = try CommandParser.init(self.editor.allocator, &self.editor.buffer_selector, &self.editor.client.status);
    defer parser.deinit();
    if (self.parseAsResourceCommand(raw_command_line)) |*command_line| {
        defer command_line.deinit();
        if (self.editor.resource_registry.get(command_line.method_name)) |command|
            try command(self.editor, command_line.params)
        else |_|
            try self.evaluateAsModuleCommand(raw_command_line);
    } else |_| try self.evaluateAsModuleCommand(raw_command_line);
}

fn parseAsResourceCommand(self: *CommandEvaluator, raw_command_line: UnicodeString) !CommandLine {
    var parser = try CommandParser.init(self.editor.allocator, &self.editor.buffer_selector, &self.editor.client.status);
    defer parser.deinit();
    return parser.parse(raw_command_line.buffer.items);
}

fn evaluateAsModuleCommand(self: *CommandEvaluator, raw_command_line: UnicodeString) !void {
    var definitions = std.ArrayList(ModuleDefinition.Command).init(self.editor.allocator);
    defer definitions.deinit();
    var it = self.editor.module_registry.iterator();
    while (it.next()) |module|
        try definitions.append(module.definition.command);
    const definitions_os = try definitions.toOwnedSlice();
    defer self.editor.allocator.free(definitions_os);
    var command = try CommandParser3.parse(self.editor.allocator, definitions_os, raw_command_line.buffer.items);
    defer command.deinit();
    var module = self.editor.module_registry.get(command.name) orelse unreachable;
    try module.runCommand(command, undefined, undefined);
}

pub fn evaluateFormat(self: *CommandEvaluator, comptime fmt: []const u8, args: anytype) !void {
    const command = try std.fmt.allocPrint(self.editor.allocator, fmt, args);
    defer self.editor.allocator.free(command);
    var command_u = try UnicodeString.init(self.editor.allocator);
    defer command_u.deinit();
    try command_u.appendSlice(command);
    try self.evaluate(command_u);
}
