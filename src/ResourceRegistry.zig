const std = @import("std");
const builtin_commands = @import("builtin_commands.zig");
const Editor = @import("Editor.zig");
const Resource = @import("Resource.zig");

const Command = *const fn (editor: *Editor, arguments: [][]const u8) anyerror!void;

allocator: std.mem.Allocator,
commands: std.StringHashMap(Command),
resources: std.StringHashMap(Resource),

pub fn init(allocator: std.mem.Allocator) @This() {
    return .{
        .allocator = allocator,
        .commands = std.StringHashMap(Command).init(allocator),
        .resources = std.StringHashMap(Resource).init(allocator),
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

pub fn registerBuiltinResources(self: *@This()) !void {
    var file = Resource.init(self.allocator);
    errdefer file.deinit();
    try file.putMethod("open", builtin_commands.open_file);
    try file.putMethod("new", builtin_commands.new_file);
    try file.putMethod("save", builtin_commands.save_file);
    try self.resources.putNoClobber("file", file);
    errdefer self.resources.remove("file");
}

pub fn deinit(self: *@This()) void {
    self.commands.deinit();
    var methods = self.resources.valueIterator();
    while (methods.next()) |method| {
        method.deinit();
    }
    self.resources.deinit();
}
