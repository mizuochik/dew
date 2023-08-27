const std = @import("std");
const dew = @import("../../dew.zig");
const Event = dew.models.Event;
const EventPublisher = dew.event.EventPublisher(Event);

const Allocator = std.mem.Allocator;

const StatusBar = @This();

message: []const u8,
event_publisher: *EventPublisher,
allocator: Allocator,

pub fn init(allocator: Allocator, event_publisher: *EventPublisher) !StatusBar {
    var empty_message = try allocator.alloc(u8, 0);
    errdefer allocator.free(empty_message);
    return .{
        .allocator = allocator,
        .message = empty_message,
        .event_publisher = event_publisher,
    };
}

pub fn deinit(self: *const StatusBar) void {
    self.allocator.free(self.message);
}

pub fn setMessage(self: *StatusBar, message: []const u8) !void {
    self.allocator.free(self.message);
    self.message = message;
    try self.event_publisher.publish(Event.status_bar_updated);
}
