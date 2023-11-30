const std = @import("std");
const dew = @import("../../dew.zig");

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

buffer: *const dew.models.Buffer,
rows: std.ArrayList(RowSlice),
width: usize,
height: usize,
y_scroll: usize = 0,
view_event_publisher: *const dew.event.Publisher(dew.view.Event),
is_active: bool,
last_cursor_x: usize = 0,
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator, buffer: *const dew.models.Buffer, vevents: *const dew.event.Publisher(dew.view.Event)) BufferView {
    const rows = std.ArrayList(RowSlice).init(allocator);
    errdefer rows.deinit();
    return .{
        .buffer = buffer,
        .rows = rows,
        .width = 0,
        .height = 0,
        .view_event_publisher = vevents,
        .is_active = buffer.mode != dew.models.Buffer.Mode.command,
        .allocator = allocator,
    };
}

pub fn deinit(self: *const BufferView) void {
    self.rows.deinit();
}

pub fn viewRow(self: *const BufferView, y: usize) []const u8 {
    const y_offset = y + self.y_scroll;
    if (y_offset >= self.rows.items.len) {
        return empty;
    }
    const row = self.rows.items[y_offset];
    return self.buffer.rows.items[row.buf_y].sliceAsRaw(row.buf_x_start, row.buf_x_end);
}

pub fn viewCursor(self: *const BufferView) ?dew.models.Position {
    if (!self.is_active) {
        return null;
    }
    const cursor = self.getCursor();
    const y_offset = if (cursor.y >= self.y_scroll) cursor.y - self.y_scroll else return null;
    if (y_offset >= self.height) {
        return null;
    }
    return .{
        .x = cursor.x,
        .y = y_offset,
    };
}

pub fn getCursor(self: *const BufferView) dew.models.Position {
    const c_y = self.buffer.cursors.items[0].y;
    const c_x = self.buffer.cursors.items[0].x;
    if (self.rows.items.len <= 0) {
        return .{
            .x = 0,
            .y = 0,
        };
    }
    var j: usize = self.rows.items.len;
    const y = while (j > 0) : (j -= 1) {
        const row = self.rows.items[j - 1];
        if (row.buf_y == c_y and row.buf_x_start <= c_x and c_x <= row.buf_x_end)
            break j - 1;
    } else 0;
    const row_slice = self.rows.items[y];
    const x = for (row_slice.buf_x_start..row_slice.buf_x_end + 1) |i| {
        if (i == c_x) {
            const buf_row = self.buffer.rows.items[row_slice.buf_y];
            break buf_row.width_index.items[i] - buf_row.width_index.items[row_slice.buf_x_start];
        }
    } else 0;
    return .{
        .x = x,
        .y = y,
    };
}

pub fn getNumberOfLines(self: *const BufferView) usize {
    return self.rows.items.len;
}

pub fn getBufferPopsition(self: *const BufferView, view_position: dew.models.Position) dew.models.Position {
    const row_slice = self.rows.items[view_position.y];
    const buffer_row = self.buffer.rows.items[row_slice.buf_y];
    const start_width = buffer_row.width_index.items[row_slice.buf_x_start];
    const buf_x = for (row_slice.buf_x_start..row_slice.buf_x_end) |bx| {
        const view_x = buffer_row.width_index.items[bx] - start_width;
        if (view_x >= view_position.x) {
            break bx;
        }
    } else row_slice.buf_x_end;
    return .{
        .x = buf_x,
        .y = row_slice.buf_y,
    };
}

pub fn scrollTo(self: *BufferView, y_scroll: usize) void {
    self.y_scroll = if (self.rows.items.len < y_scroll)
        self.rows.items.len
    else
        y_scroll;
}

pub fn normalizeScroll(self: *BufferView) void {
    const cursor = self.getCursor();
    const edge_height = self.height / 16;
    const upper_limit = self.y_scroll + edge_height;
    const bottom_limit = self.y_scroll + self.height - edge_height;
    if (cursor.y < upper_limit) {
        self.y_scroll = if (cursor.y > edge_height) cursor.y - edge_height else 0;
    }
    if (cursor.y >= bottom_limit) {
        self.y_scroll = cursor.y + edge_height - self.height;
    }
}

pub fn getNormalizedCursor(self: *BufferView) dew.models.Position {
    const upper_limit = self.y_scroll + self.height / 16;
    const bottom_limit = self.y_scroll + self.height * 15 / 16;
    const cursor = self.getCursor();
    if (cursor.y < upper_limit) {
        return .{ .x = cursor.x, .y = upper_limit };
    }
    if (cursor.y >= bottom_limit) {
        return .{ .x = cursor.x, .y = bottom_limit - 1 };
    }
    return cursor;
}

pub fn updateLastCursorX(self: *BufferView) void {
    self.last_cursor_x = self.getCursor().x;
}

pub fn eventSubscriber(self: *BufferView) dew.event.Subscriber(dew.models.Event) {
    return dew.event.Subscriber(dew.models.Event){
        .ptr = self,
        .vtable = &.{
            .handle = handleEvent,
        },
    };
}

fn handleEvent(ctx: *anyopaque, event: dew.models.Event) anyerror!void {
    const self: *BufferView = @ptrCast(@alignCast(ctx));
    switch (event) {
        .cursor_moved => {
            self.normalizeScroll();
            try self.view_event_publisher.publish(switch (self.buffer.mode) {
                .file => .buffer_view_updated,
                .command => .command_buffer_view_updated,
            });
        },
        .buffer_updated => |_| {
            try self.update();
            try self.view_event_publisher.publish(switch (self.buffer.mode) {
                .file => .buffer_view_updated,
                .command => .command_buffer_view_updated,
            });
        },
        .screen_size_changed => |new_size| {
            self.width = new_size.width;
            self.height = switch (self.buffer.mode) {
                .file => new_size.height - 1,
                .command => 1,
            };
            try self.update();
            try self.view_event_publisher.publish(.buffer_view_updated);
        },
        .command_buffer_opened => {
            self.is_active = self.buffer.mode == dew.models.Buffer.Mode.command;
            try self.view_event_publisher.publish(.buffer_view_updated);
        },
        .command_buffer_closed => {
            self.is_active = self.buffer.mode != dew.models.Buffer.Mode.command;
            try self.view_event_publisher.publish(.buffer_view_updated);
        },
        else => {},
    }
}

fn update(self: *BufferView) !void {
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
        }
        if (row.getLen() <= 0 or x_start < row.getLen()) {
            try new_rows.append(RowSlice{
                .buf_y = y,
                .buf_x_start = x_start,
                .buf_x_end = row.getLen(),
            });
        }
    }
    self.rows.deinit();
    self.rows = new_rows;
}

pub fn scrollUp(self: *BufferView, diff: usize) void {
    if (self.y_scroll < diff)
        self.y_scroll = 0
    else
        self.y_scroll -= diff;
}

pub fn scrollDown(self: *BufferView, diff: usize) void {
    const max_scroll = self.rows.items.len - self.height / 16 - 1;
    if (self.y_scroll + diff > max_scroll)
        self.y_scroll = max_scroll
    else
        self.y_scroll += diff;
}

test "BufferView: init" {
    var view_event_publisher = dew.event.Publisher(dew.view.Event).init(std.testing.allocator);
    defer view_event_publisher.deinit();
    var model_event_publisher = dew.event.Publisher(dew.models.Event).init(std.testing.allocator);
    defer model_event_publisher.deinit();
    const buf = try dew.models.Buffer.init(std.testing.allocator, &model_event_publisher, .file);
    defer buf.deinit();
    const bv = BufferView.init(std.testing.allocator, &buf, &view_event_publisher, .file);
    defer bv.deinit();
}

test "BufferView: scrollTo" {
    var view_event_publisher = dew.event.Publisher(dew.view.Event).init(std.testing.allocator);
    defer view_event_publisher.deinit();
    var model_event_publisher = dew.event.Publisher(dew.models.Event).init(std.testing.allocator);
    defer model_event_publisher.deinit();
    var buf = try dew.models.Buffer.init(std.testing.allocator, &model_event_publisher, .file);
    defer buf.deinit();
    for ([_][]const u8{
        "abc",
        "def",
    }) |line| {
        var s = try dew.models.UnicodeString.init(std.testing.allocator);
        errdefer s.deinit();
        try s.appendSlice(line);
        try buf.rows.append(s);
    }
    var bv = BufferView.init(std.testing.allocator, &buf, &view_event_publisher, .file);
    defer bv.deinit();
    try model_event_publisher.addSubscriber(bv.eventSubscriber());
    try model_event_publisher.publish(.{ .screen_size_changed = .{ .width = 99, .height = 5 } });
    try buf.notifyUpdate();

    try std.testing.expectEqual(@as(usize, 0), bv.y_scroll);

    bv.scrollTo(2);
    try std.testing.expectEqual(@as(usize, 2), bv.y_scroll);

    bv.scrollTo(2);
    try std.testing.expectEqual(@as(usize, 2), bv.y_scroll);
}

test "BufferView: update" {
    var view_event_publisher = dew.event.Publisher(dew.view.Event).init(std.testing.allocator);
    defer view_event_publisher.deinit();
    var model_event_publisher = dew.event.Publisher(dew.models.Event).init(std.testing.allocator);
    defer model_event_publisher.deinit();
    var buf = try dew.models.Buffer.init(std.testing.allocator, &model_event_publisher, .file);
    defer buf.deinit();
    for ([_][]const u8{
        "abcdefghij",
        "あいうえお",
        "松竹",
        "",
        "あ",
    }) |line| {
        var s = try dew.models.UnicodeString.init(std.testing.allocator);
        errdefer s.deinit();
        try s.appendSlice(line);
        try buf.rows.append(s);
    }
    var bv = BufferView.init(std.testing.allocator, &buf, &view_event_publisher, .file);
    defer bv.deinit();
    try model_event_publisher.addSubscriber(bv.eventSubscriber());
    try model_event_publisher.publish(.{ .screen_size_changed = .{ .width = 5, .height = 100 } });
    try buf.notifyUpdate();

    try std.testing.expectEqual(@as(usize, 8), bv.rows.items.len);
    try std.testing.expectEqualStrings("abcde", bv.getRowView(0));
    try std.testing.expectEqualStrings("fghij", bv.getRowView(1));
    try std.testing.expectEqualStrings("あい", bv.getRowView(2));
    try std.testing.expectEqualStrings("うえ", bv.getRowView(3));
    try std.testing.expectEqualStrings("お", bv.getRowView(4));
    try std.testing.expectEqualStrings("松竹", bv.getRowView(5));
    try std.testing.expectEqualStrings("", bv.getRowView(6));
    try std.testing.expectEqualStrings("あ", bv.getRowView(7));
}

test "BufferView: getCursor" {
    var view_event_publisher = dew.event.Publisher(dew.view.Event).init(std.testing.allocator);
    defer view_event_publisher.deinit();
    var model_event_publisher = dew.event.Publisher(dew.models.Event).init(std.testing.allocator);
    defer model_event_publisher.deinit();
    var buf = try dew.models.Buffer.init(std.testing.allocator, &model_event_publisher, .file);
    defer buf.deinit();
    for ([_][]const u8{
        "abcdefghij",
        "あいうえお",
        "松竹",
    }) |line| {
        var s = try dew.models.UnicodeString.init(std.testing.allocator);
        errdefer s.deinit();
        try s.appendSlice(line);
        try buf.rows.append(s);
    }
    var bv = BufferView.init(std.testing.allocator, &buf, &view_event_publisher, .file);
    defer bv.deinit();
    try model_event_publisher.addSubscriber(bv.eventSubscriber());
    try model_event_publisher.publish(.{ .screen_size_changed = .{ .width = 5, .height = 99 } });
    try buf.notifyUpdate();

    buf.c_x = 1;
    buf.c_y = 2;
    try std.testing.expectFmt("(2, 5)", "{}", .{bv.getCursor()});
}

test "BufferView: getBufferPosition" {
    var view_event_publisher = dew.event.Publisher(dew.view.Event).init(std.testing.allocator);
    defer view_event_publisher.deinit();
    var model_event_publisher = dew.event.Publisher(dew.models.Event).init(std.testing.allocator);
    defer model_event_publisher.deinit();
    var buf = try dew.models.Buffer.init(std.testing.allocator, &model_event_publisher, .file);
    defer buf.deinit();
    for ([_][]const u8{
        "abcdefghij",
        "あいうえお",
        "松竹",
    }) |line| {
        var s = try dew.models.UnicodeString.init(std.testing.allocator);
        errdefer s.deinit();
        try s.appendSlice(line);
        try buf.rows.append(s);
    }
    var bv = BufferView.init(std.testing.allocator, &buf, &view_event_publisher, .file);
    defer bv.deinit();
    try model_event_publisher.addSubscriber(bv.eventSubscriber());
    try model_event_publisher.publish(.{ .screen_size_changed = .{ .width = 5, .height = 99 } });
    try buf.notifyUpdate();

    {
        const actual = bv.getBufferPopsition(.{ .x = 0, .y = 0 });
        try std.testing.expectFmt("(0, 0)", "{}", .{actual});
    }
    {
        const actual = bv.getBufferPopsition(.{ .x = 1, .y = 1 });
        try std.testing.expectFmt("(6, 0)", "{}", .{actual});
    }
    {
        const actual = bv.getBufferPopsition(.{ .x = 2, .y = 2 });
        try std.testing.expectFmt("(1, 1)", "{}", .{actual});
    }
}
