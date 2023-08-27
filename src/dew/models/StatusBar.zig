const std = @import("std");
const dew = @import("../../dew.zig");
const Observer = dew.event.Observer;
const Event = dew.event.Event;

const Allocator = std.mem.Allocator;

const StatusBar = @This();

message: []const u8,
observer: *Observer,
allocator: Allocator,

pub fn init(allocator: Allocator) !StatusBar {
    var empty_message = try allocator.alloc(u8, 0);
    errdefer allocator.free(empty_message);
    return .{
        .allocator = allocator,
        .message = empty_message,
    };
}

pub fn deinit(self: *const StatusBar) void {
    self.allocator.free(self.message);
}

pub fn setMessage(self: *StatusBar, message: []const u8) !void {
    self.allocator.free(self.message);
    self.message = message;
    try self.observer.update(.status_bar_updated);
}
