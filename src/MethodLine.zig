const std = @import("std");

allocator: std.mem.Allocator,
method_name: []const u8,
params: [][]const u8,

pub fn deinit(self: *const @This()) void {
    self.allocator.free(self.method_name);
    for (self.params) |argument| {
        self.allocator.free(argument);
    }
    self.allocator.free(self.params);
}
