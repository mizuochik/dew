const std = @import("std");
const dew = @import("../../dew.zig");
const Event = dew.models.Event;
const Publisher = dew.event.Publisher(Event);

const Allocator = std.mem.Allocator;

const StatusMessage = @This();

message: []const u8,
allocator: Allocator,

pub fn init(allocator: Allocator) !StatusMessage {
    var empty_message = try allocator.alloc(u8, 0);
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
