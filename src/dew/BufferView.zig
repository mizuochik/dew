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
allocator: mem.Allocator,

pub fn init(allocator: mem.Allocator, buffer: *const dew.Buffer) !BufferView {
    const rows = std.ArrayList(RowSlice).init(allocator);
    errdefer rows.deinit();
    return .{
        .buffer = buffer,
        .rows = rows,
        .allocator = allocator,
    };
}

pub fn deinit(self: *const BufferView) void {
    self.rows.deinit();
}

test "BufferView: init" {
    const buf = dew.Buffer.init(testing.allocator);
    defer buf.deinit();
    const bv = try BufferView.init(testing.allocator, &buf);
    defer bv.deinit();
}
