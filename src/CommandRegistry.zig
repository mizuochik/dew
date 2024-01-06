const std = @import("std");
const commands = @import("commands.zig");
const Command = @import("Command.zig");

const CommandRegistry = @This();

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
    const cmd_open_file = try commands.OpenFile.init(self.allocator);
    errdefer cmd_open_file.deinit();
    try self.commands.putNoClobber("open-file", cmd_open_file);
    errdefer _ = self.commands.remove("open-file");

    const cmd_new_file = try commands.NewFile.init(self.allocator);
    errdefer cmd_new_file.deinit();
    try self.commands.putNoClobber("new-file", cmd_new_file);
    errdefer _ = self.commands.remove("new-file");

    const cmd_save_file = try commands.SaveFile.init(self.allocator);
    errdefer cmd_save_file.deinit();
    try self.commands.putNoClobber("save-file", cmd_save_file);
    errdefer _ = self.commands.remove("save-file");
}

pub fn deinit(self: *CommandRegistry) void {
    var it = self.commands.iterator();
    while (it.next()) |entry| {
        entry.value_ptr.deinit();
    }
    self.commands.deinit();
}
