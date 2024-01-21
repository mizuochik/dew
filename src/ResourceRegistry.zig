const std = @import("std");
const builtin_commands = @import("builtin_commands.zig");
const Editor = @import("Editor.zig");

const Command = *const fn (editor: *Editor, arguments: [][]const u8) anyerror!void;

allocator: std.mem.Allocator,
commands: std.StringHashMap(Command),

pub fn init(allocator: std.mem.Allocator) @This() {
    return .{
        .allocator = allocator,
        .commands = std.StringHashMap(Command).init(allocator),
    };
}

pub fn get(self: *const @This(), name: []const u8) !Command {
    return self.commands.get(name) orelse error.CommandNotFound;
}

pub fn registerCommand(self: *@This(), name: []const u8, command: Command) !void {
    try self.commands.putNoClobber(name, command);
}

pub fn registerBuiltinCommands(self: *@This()) !void {
    try self.commands.putNoClobber("open-file", builtin_commands.open_file);
    errdefer _ = self.commands.remove("open-file");
    try self.commands.putNoClobber("new-file", builtin_commands.new_file);
    errdefer _ = self.commands.remove("new-file");
    try self.commands.putNoClobber("save-file", builtin_commands.save_file);
    errdefer _ = self.commands.remove("save-file");
}

pub fn deinit(self: *@This()) void {
    self.commands.deinit();
}
