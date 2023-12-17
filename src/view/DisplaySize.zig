const std = @import("std");
const event = @import("../event.zig");
const view = @import("../view.zig");

const DisplaySize = @This();

cols: usize,
rows: usize,
event_publisher: *event.Publisher(view.Event),

pub fn init(event_publisher: *event.Publisher(view.Event)) DisplaySize {
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
