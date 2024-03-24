const Status = @This();
const std = @import("std");

message: []const u8,
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) !Status {
    const empty_message = try allocator.alloc(u8, 0);
    errdefer allocator.free(empty_message);
    return .{
        .allocator = allocator,
        .message = empty_message,
    };
}

pub fn deinit(self: *const Status) void {
    self.allocator.free(self.message);
}

pub fn setMessage(self: *Status, message: []const u8) !void {
    self.allocator.free(self.message);
    self.message = message;
}
