const std = @import("std");
const mem = std.mem;
const dew = @import("../../dew.zig");
const observer = dew.observer;

const Self = @This();

pub const Event = union(enum) {
    changed: Self,
};

cols: usize,
rows: usize,
observer_list: observer.ObserverList(Event),

pub fn init(allocator: mem.Allocator) Self {
    return .{
        .cols = 0,
        .rows = 0,
        .observer_list = observer.ObserverList(Event).init(allocator),
    };
}

pub fn deinit(self: *const Self) void {
    self.observer_list.deinit();
}

pub fn set(self: *Self, cols: usize, rows: usize) !void {
    self.cols = cols;
    self.rows = rows;
    try self.observer_list.notifyEvent(.{ .changed = self.* });
}

pub fn addObserver(self: *Self, obs: observer.Observer(Event)) !void {
    try self.observer_list.add(obs);
}
