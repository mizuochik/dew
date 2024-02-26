const std = @import("std");

const CommandLine = @This();

pub const Arguments = struct {
    allocator: std.mem.Allocator,
    optionals: std.StringHashMap([]const u8),
    positionals: []const []const u8,
    subcommand: ?*CommandLine = null,

    pub fn deinit(self: *@This()) void {
        var it = self.optionals.iterator();
        while (it.next()) |entry| {
            entry.key_ptr.deinit();
            entry.value_ptr.deinit();
        }
        self.optionals.deinit();
        for (self.positionals) |positional|
            self.allocator.free(positional);
        if (self.subcommand) |subcommand|
            subcommand.deinit();
    }
};

allocator: std.mem.Allocator,
method_name: []const u8,
params: [][]const u8,
arguments: *const Arguments,

pub fn deinit(self: *const @This()) void {
    self.allocator.free(self.method_name);
    for (self.params) |argument| {
        self.allocator.free(argument);
    }
    self.allocator.free(self.params);
}
