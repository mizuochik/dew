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

const empty: []const u8 = b: {
    const s: [0]u8 = undefined;
    break :b &s;
};

buffer: *const dew.Buffer,
rows: std.ArrayList(RowSlice),
width: usize,
height: usize,
y_scroll: usize = 0,
allocator: mem.Allocator,

pub fn init(allocator: mem.Allocator, buffer: *const dew.Buffer, width: usize, height: usize) !BufferView {
    const rows = std.ArrayList(RowSlice).init(allocator);
    errdefer rows.deinit();
    return .{
        .buffer = buffer,
        .rows = rows,
        .width = width,
        .height = height,
        .allocator = allocator,
    };
}

pub fn deinit(self: *const BufferView) void {
    self.rows.deinit();
}

pub fn getRowView(self: *const BufferView, y: usize) []const u8 {
    const offset = y + self.y_scroll;
    if (offset < 0)
        return empty;
    if (offset >= self.rows.items.len)
        return empty;
    const row_slice = self.rows.items[offset];
    return self.buffer.rows.items[row_slice.buf_y].sliceAsRaw(row_slice.buf_x_start, row_slice.buf_x_end);
}

pub fn scrollTo(self: *BufferView, y_scroll: usize) void {
    self.y_scroll = if (y_scroll > self.rows.items.len)
        self.rows.items.len
    else
        y_scroll;
}

fn update(ctx: *anyopaque) !void {
    const self = @ptrCast(*BufferView, @alignCast(@alignOf(BufferView), ctx));
    var new_rows = std.ArrayList(RowSlice).init(self.allocator);
    errdefer new_rows.deinit();
    for (self.buffer.rows.items, 0..) |row, y| {
        var x_start: usize = 0;
        for (0..row.getLen()) |x| {
            if (row.width_index.items[x + 1] - row.width_index.items[x_start] > self.width) {
                try new_rows.append(RowSlice{
                    .buf_y = y,
                    .buf_x_start = x_start,
                    .buf_x_end = x,
                });
                x_start = x;
            }
            if (x + 1 >= row.getLen()) {
                try new_rows.append(RowSlice{
                    .buf_y = y,
                    .buf_x_start = x_start,
                    .buf_x_end = row.getLen(),
                });
                x_start = 0;
            }
        }
    }
    self.rows.deinit();
    self.rows = new_rows;
}

pub fn asView(self: *BufferView) dew.View {
    return .{
        .ptr = self,
        .vtable = &.{
            .update = update,
        },
    };
}

test "BufferView: init" {
    const buf = dew.Buffer.init(testing.allocator);
    defer buf.deinit();
    const bv = try BufferView.init(testing.allocator, &buf, 10, 10);
    defer bv.deinit();
}

test "BufferView: scrollTo" {
    var buf = dew.Buffer.init(testing.allocator);
    defer buf.deinit();
    for ([_][]const u8{
        "a",
        "b",
        "c",
        "d",
    }) |line| {
        var s = try dew.UnicodeString.init(testing.allocator);
        errdefer s.deinit();
        try s.appendSlice(line);
        try buf.rows.append(s);
    }
    var bv = try BufferView.init(testing.allocator, &buf, 99, 4);
    defer bv.deinit();
    try buf.bindView(bv.asView());
    try buf.updateViews();

    try testing.expectEqualStrings("a", bv.getRowView(0));
    try testing.expectEqualStrings("d", bv.getRowView(3));

    bv.scrollTo(1);
    try testing.expectEqualStrings("b", bv.getRowView(0));
    try testing.expectEqualStrings("", bv.getRowView(4));

    bv.scrollTo(4);
    try testing.expectEqualStrings("", bv.getRowView(0));
    try testing.expectEqualStrings("", bv.getRowView(4));

    bv.scrollTo(5);
    try testing.expectEqualStrings("", bv.getRowView(0));
    try testing.expectEqualStrings("", bv.getRowView(4));
}

test "BufferView: update" {
    var buf = dew.Buffer.init(testing.allocator);
    defer buf.deinit();
    for ([_][]const u8{
        "abcdefghij",
        "あいうえお",
        "松竹",
    }) |line| {
        var s = try dew.UnicodeString.init(testing.allocator);
        errdefer s.deinit();
        try s.appendSlice(line);
        try buf.rows.append(s);
    }
    var bv = try BufferView.init(testing.allocator, &buf, 5, 99);
    defer bv.deinit();
    try buf.bindView(bv.asView());
    try buf.updateViews();

    try testing.expectEqual(@as(usize, 6), bv.rows.items.len);
    try testing.expectEqualStrings("abcde", bv.getRowView(0));
    try testing.expectEqualStrings("fghij", bv.getRowView(1));
    try testing.expectEqualStrings("あい", bv.getRowView(2));
    try testing.expectEqualStrings("うえ", bv.getRowView(3));
    try testing.expectEqualStrings("お", bv.getRowView(4));
    try testing.expectEqualStrings("松竹", bv.getRowView(5));
}