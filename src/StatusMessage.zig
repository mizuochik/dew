const std = @import("std");
const models = @import("models.zig");

const StatusMessage = @This();

message: []const u8,
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) !StatusMessage {
    const empty_message = try allocator.alloc(u8, 0);
    errdefer allocator.free(empty_message);
    return .{
        .allocator = allocator,
        .message = empty_message,
    };
}

pub fn deinit(self: *const StatusMessage) void {
    self.allocator.free(self.message);
}

pub fn setMessage(self: *StatusMessage, message: []const u8) !void {
    self.allocator.free(self.message);
    self.message = message;
}
