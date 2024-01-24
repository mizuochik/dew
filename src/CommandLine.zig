const std = @import("std");

allocator: std.mem.Allocator,
command_name: []const u8,
arguments: [][]const u8,

pub fn deinit(self: *const @This()) void {
    self.allocator.free(self.command_name);
    for (self.arguments) |argument| {
        self.allocator.free(argument);
    }
    self.allocator.free(self.arguments);
}
