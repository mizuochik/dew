const std = @import("std");
const event = @import("../event.zig");
const models = @import("../models.zig");

const StatusMessage = @This();

message: []const u8,
event_publisher: *event.Publisher(models.Event),
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator, event_publisher: *event.Publisher(models.Event)) !StatusMessage {
    const empty_message = try allocator.alloc(u8, 0);
    errdefer allocator.free(empty_message);
    return .{
        .allocator = allocator,
        .message = empty_message,
        .event_publisher = event_publisher,
    };
}

pub fn deinit(self: *const StatusMessage) void {
    self.allocator.free(self.message);
}

pub fn setMessage(self: *StatusMessage, message: []const u8) !void {
    self.allocator.free(self.message);
    self.message = message;
    try self.event_publisher.publish(models.Event.status_message_updated);
}
