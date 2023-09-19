const std = @import("std");
const mem = std.mem;
const testing = std.testing;
const dew = @import("../../dew.zig");
const view = dew.view;
const observer = dew.observer;
const Buffer = dew.models.Buffer;
const Position = dew.models.Position;
const models = dew.models;
const Publisher = dew.event.Publisher;
const Subscriber = dew.event.Subscriber;
const UnicodeString = dew.models.UnicodeString;

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

const Mode = enum {
    file,
    command,
};

buffer: *const Buffer,
rows: std.ArrayList(RowSlice),
width: usize,
height: usize,
y_scroll: usize = 0,
view_event_publisher: *const Publisher(view.Event),
last_cursor_x: usize = 0,
allocator: mem.Allocator,

pub fn init(allocator: mem.Allocator, buffer: *const Buffer, vevents: *const Publisher(view.Event)) BufferView {
    const rows = std.ArrayList(RowSlice).init(allocator);
    errdefer rows.deinit();
    return .{
        .buffer = buffer,
        .rows = rows,
        .width = 0,
        .height = 0,
        .view_event_publisher = vevents,
        .allocator = allocator,
    };
}

pub fn deinit(self: *const BufferView) void {
    self.rows.deinit();
}

pub fn getRowView(self: *const BufferView, y: usize) []const u8 {
    if (y >= self.rows.items.len)
        return empty;
    const row_slice = self.rows.items[y];
    return self.buffer.rows.items[row_slice.buf_y].sliceAsRaw(row_slice.buf_x_start, row_slice.buf_x_end);
}

pub fn getCursor(self: *const BufferView) Position {
    var j: usize = self.rows.items.len - 1;
    const y = while (true) {
        const row = self.rows.items[j];
        if (row.buf_y == self.buffer.c_y and row.buf_x_start <= self.buffer.c_x and self.buffer.c_x <= row.buf_x_end)
            break j;
        if (j <= 0)
            break 0;
        j -= 1;
    };
    const row_slice = self.rows.items[y];
    var x = for (row_slice.buf_x_start..row_slice.buf_x_end + 1) |i| {
        if (i == self.buffer.c_x) {
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

pub fn getBufferPopsition(self: *const BufferView, view_position: Position) Position {
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
    const upper_limit = self.y_scroll + self.height / 16;
    const bottom_limit = self.y_scroll + self.height * 15 / 16;
    if (cursor.y < upper_limit and cursor.y >= self.height / 16) {
        self.y_scroll = cursor.y - self.height / 16;
    }
    if (cursor.y >= bottom_limit) {
        self.y_scroll = cursor.y - self.height * 15 / 16;
    }
}

pub fn getNormalizedCursor(self: *BufferView) Position {
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

pub fn isActive(self: *BufferView) bool {
    return self.buffer.is_active;
}

fn handleEvent(ctx: *anyopaque, event: models.Event) anyerror!void {
    const self: *BufferView = @ptrCast(@alignCast(ctx));
    switch (event) {
        .buffer_updated => |_| {
            try self.update();
            try self.view_event_publisher.publish(.buffer_view_updated);
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
            try self.view_event_publisher.publish(.buffer_view_updated);
        },
        .command_buffer_closed => {
            try self.view_event_publisher.publish(.buffer_view_updated);
        },
        else => {},
    }
}

pub fn eventSubscriber(self: *BufferView) Subscriber(models.Event) {
    return Subscriber(models.Event){
        .ptr = self,
        .vtable = &.{
            .handle = handleEvent,
        },
    };
}

pub fn bufferObserver(self: *BufferView) observer.Observer(Buffer.Event) {
    return .{
        .ptr = self,
        .vtable = &.{
            .handleEvent = handleBufferEvent,
        },
    };
}

fn handleBufferEvent(ctx: *anyopaque, event: Buffer.Event) anyerror!void {
    const self: *BufferView = @ptrCast(@alignCast(ctx));
    switch (self.buffer.mode) {
        .file => switch (event) {
            .updated => |_| {
                try self.update();
                try self.view_event_publisher.publish(.buffer_view_updated);
            },
            else => {},
        },
        .command => switch (event) {
            .activated, .deactivated => {
                try self.view_event_publisher.publish(.buffer_view_updated);
            },
            else => {},
        },
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
    var view_event_publisher = Publisher(view.Event).init(testing.allocator);
    defer view_event_publisher.deinit();
    var model_event_publisher = Publisher(models.Event).init(testing.allocator);
    defer model_event_publisher.deinit();
    const buf = Buffer.init(testing.allocator, &model_event_publisher, .file);
    defer buf.deinit();
    const bv = BufferView.init(testing.allocator, &buf, &view_event_publisher, .file);
    defer bv.deinit();
}

test "BufferView: scrollTo" {
    var view_event_publisher = Publisher(view.Event).init(testing.allocator);
    defer view_event_publisher.deinit();
    var model_event_publisher = Publisher(models.Event).init(testing.allocator);
    defer model_event_publisher.deinit();
    var buf = Buffer.init(testing.allocator, &model_event_publisher, .file);
    defer buf.deinit();
    for ([_][]const u8{
        "abc",
        "def",
    }) |line| {
        var s = try UnicodeString.init(testing.allocator);
        errdefer s.deinit();
        try s.appendSlice(line);
        try buf.rows.append(s);
    }
    var bv = BufferView.init(testing.allocator, &buf, &view_event_publisher, .file);
    defer bv.deinit();
    try model_event_publisher.addSubscriber(bv.eventSubscriber());
    try model_event_publisher.publish(.{ .screen_size_changed = .{ .width = 99, .height = 5 } });
    try buf.notifyUpdate();

    try testing.expectEqual(@as(usize, 0), bv.y_scroll);

    bv.scrollTo(2);
    try testing.expectEqual(@as(usize, 2), bv.y_scroll);

    bv.scrollTo(2);
    try testing.expectEqual(@as(usize, 2), bv.y_scroll);
}

test "BufferView: update" {
    var view_event_publisher = Publisher(view.Event).init(testing.allocator);
    defer view_event_publisher.deinit();
    var model_event_publisher = Publisher(models.Event).init(testing.allocator);
    defer model_event_publisher.deinit();
    var buf = Buffer.init(testing.allocator, &model_event_publisher, .file);
    defer buf.deinit();
    for ([_][]const u8{
        "abcdefghij",
        "あいうえお",
        "松竹",
        "",
        "あ",
    }) |line| {
        var s = try UnicodeString.init(testing.allocator);
        errdefer s.deinit();
        try s.appendSlice(line);
        try buf.rows.append(s);
    }
    var bv = BufferView.init(testing.allocator, &buf, &view_event_publisher, .file);
    defer bv.deinit();
    try model_event_publisher.addSubscriber(bv.eventSubscriber());
    try model_event_publisher.publish(.{ .screen_size_changed = .{ .width = 5, .height = 100 } });
    try buf.notifyUpdate();

    try testing.expectEqual(@as(usize, 8), bv.rows.items.len);
    try testing.expectEqualStrings("abcde", bv.getRowView(0));
    try testing.expectEqualStrings("fghij", bv.getRowView(1));
    try testing.expectEqualStrings("あい", bv.getRowView(2));
    try testing.expectEqualStrings("うえ", bv.getRowView(3));
    try testing.expectEqualStrings("お", bv.getRowView(4));
    try testing.expectEqualStrings("松竹", bv.getRowView(5));
    try testing.expectEqualStrings("", bv.getRowView(6));
    try testing.expectEqualStrings("あ", bv.getRowView(7));
}

test "BufferView: getCursor" {
    var view_event_publisher = Publisher(view.Event).init(testing.allocator);
    defer view_event_publisher.deinit();
    var model_event_publisher = Publisher(models.Event).init(testing.allocator);
    defer model_event_publisher.deinit();
    var buf = Buffer.init(testing.allocator, &model_event_publisher, .file);
    defer buf.deinit();
    for ([_][]const u8{
        "abcdefghij",
        "あいうえお",
        "松竹",
    }) |line| {
        var s = try UnicodeString.init(testing.allocator);
        errdefer s.deinit();
        try s.appendSlice(line);
        try buf.rows.append(s);
    }
    var bv = BufferView.init(testing.allocator, &buf, &view_event_publisher, .file);
    defer bv.deinit();
    try model_event_publisher.addSubscriber(bv.eventSubscriber());
    try model_event_publisher.publish(.{ .screen_size_changed = .{ .width = 5, .height = 99 } });
    try buf.notifyUpdate();

    buf.c_x = 1;
    buf.c_y = 2;
    try testing.expectFmt("(2, 5)", "{}", .{bv.getCursor()});
}

test "BufferView: getBufferPosition" {
    var view_event_publisher = Publisher(view.Event).init(testing.allocator);
    defer view_event_publisher.deinit();
    var model_event_publisher = Publisher(models.Event).init(testing.allocator);
    defer model_event_publisher.deinit();
    var buf = Buffer.init(testing.allocator, &model_event_publisher, .file);
    defer buf.deinit();
    for ([_][]const u8{
        "abcdefghij",
        "あいうえお",
        "松竹",
    }) |line| {
        var s = try UnicodeString.init(testing.allocator);
        errdefer s.deinit();
        try s.appendSlice(line);
        try buf.rows.append(s);
    }
    var bv = BufferView.init(testing.allocator, &buf, &view_event_publisher, .file);
    defer bv.deinit();
    try model_event_publisher.addSubscriber(bv.eventSubscriber());
    try model_event_publisher.publish(.{ .screen_size_changed = .{ .width = 5, .height = 99 } });
    try buf.notifyUpdate();

    {
        const actual = bv.getBufferPopsition(.{ .x = 0, .y = 0 });
        try testing.expectFmt("(0, 0)", "{}", .{actual});
    }
    {
        const actual = bv.getBufferPopsition(.{ .x = 1, .y = 1 });
        try testing.expectFmt("(6, 0)", "{}", .{actual});
    }
    {
        const actual = bv.getBufferPopsition(.{ .x = 2, .y = 2 });
        try testing.expectFmt("(1, 1)", "{}", .{actual});
    }
}
