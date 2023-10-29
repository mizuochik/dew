const std = @import("std");
const dew = @import("../../dew.zig");

const DisplaySize = @This();

pub const Event = union(enum) {
    changed: DisplaySize,
};

cols: usize,
rows: usize,
observer_list: dew.observer.ObserverList(Event),

pub fn init(allocator: std.mem.Allocator) DisplaySize {
    return .{
        .cols = 0,
        .rows = 0,
        .observer_list = dew.observer.ObserverList(Event).init(allocator),
    };
}

pub fn deinit(self: *const DisplaySize) void {
    self.observer_list.deinit();
}

pub fn set(self: *DisplaySize, cols: usize, rows: usize) !void {
    self.cols = cols;
    self.rows = rows;
    try self.observer_list.notifyEvent(.{ .changed = self.* });
}

pub fn addObserver(self: *DisplaySize, obs: dew.observer.Observer(Event)) !void {
    try self.observer_list.add(obs);
}
