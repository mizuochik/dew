const std = @import("std");
const view = @import("view.zig");

const DisplaySize = @This();

cols: usize,
rows: usize,

pub fn init() DisplaySize {
    return .{
        .cols = 0,
        .rows = 0,
    };
}

pub fn set(self: *DisplaySize, cols: usize, rows: usize) !void {
    self.cols = cols;
    self.rows = rows;
}
