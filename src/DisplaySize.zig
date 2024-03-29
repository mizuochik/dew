const DisplaySize = @This();
const std = @import("std");

cols: usize,
rows: usize,

pub fn init() @This() {
    return .{
        .cols = 0,
        .rows = 0,
    };
}

pub fn set(self: *DisplaySize, cols: usize, rows: usize) !void {
    self.cols = cols;
    self.rows = rows;
}
