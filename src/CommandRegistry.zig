const std = @import("std");
const builtin_commands = @import("builtin_commands.zig");
const Editor = @import("Editor.zig");

const CommandRegistry = @This();

const Command = *const fn (editor: *Editor, arguments: [][]const u8) anyerror!void;

allocator: std.mem.Allocator,
commands: std.StringHashMap(Command),

pub fn init(allocator: std.mem.Allocator) CommandRegistry {
    return .{
        .allocator = allocator,
        .commands = std.StringHashMap(Command).init(allocator),
    };
}

pub fn get(self: *const CommandRegistry, name: []const u8) !Command {
    return self.commands.get(name) orelse error.CommandNotFound;
}

pub fn registerCommand(self: *CommandRegistry, name: []const u8, command: Command) !void {
    try self.commands.putNoClobber(name, command);
}

pub fn registerBuiltinCommands(self: *CommandRegistry) !void {
    try self.commands.putNoClobber("open-file", builtin_commands.open_file);
    errdefer _ = self.commands.remove("open-file");
    try self.commands.putNoClobber("new-file", builtin_commands.new_file);
    errdefer _ = self.commands.remove("new-file");
    try self.commands.putNoClobber("save-file", builtin_commands.save_file);
    errdefer _ = self.commands.remove("save-file");
}

pub fn deinit(self: *CommandRegistry) void {
    self.commands.deinit();
}
