const std = @import("std");
const mem = std.mem;
const testing = std.testing;
const dew = @import("../dew.zig");

const BufferView = @This();

const RowSlice = struct {
    buf_y: usize,
    buf_x_start: usize,
    buf_x_end: usize,
};

buffer: *const dew.Buffer,
rows: std.ArrayList(RowSlice),
width: usize,
allocator: mem.Allocator,

pub fn init(allocator: mem.Allocator, buffer: *const dew.Buffer, width: usize) !BufferView {
    const rows = std.ArrayList(RowSlice).init(allocator);
    errdefer rows.deinit();
    return .{
        .buffer = buffer,
        .rows = rows,
        .width = width,
        .allocator = allocator,
    };
}

pub fn deinit(self: *const BufferView) void {
    self.rows.deinit();
}

test "BufferView: init" {
    const buf = dew.Buffer.init(testing.allocator);
    defer buf.deinit();
    const bv = try BufferView.init(testing.allocator, &buf, 10);
    defer bv.deinit();
}
