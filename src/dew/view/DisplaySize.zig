const std = @import("std");
const dew = @import("../../dew.zig");

const DisplaySize = @This();

cols: usize,
rows: usize,
event_publisher: *dew.event.Publisher(dew.view.Event),

pub fn init(event_publisher: *dew.event.Publisher(dew.view.Event)) DisplaySize {
    return .{
        .cols = 0,
        .rows = 0,
        .event_publisher = event_publisher,
    };
}

pub fn set(self: *DisplaySize, cols: usize, rows: usize) !void {
    self.cols = cols;
    self.rows = rows;
    try self.event_publisher.publish(.{ .screen_size_changed = .{ .width = cols, .height = rows } });
}
