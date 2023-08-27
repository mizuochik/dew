const std = @import("std");
const mem = std.mem;
const testing = std.testing;
const dew = @import("../../dew.zig");
const Editor = dew.Editor;
const Arrow = Editor.Arrow;
const View = dew.view.View;
const Event = dew.models.Event;
const EventPublisher = dew.event.EventPublisher(Event);
const UnicodeString = dew.models.UnicodeString;
const Position = dew.models.Position;

const Buffer = @This();

rows: std.ArrayList(UnicodeString),
c_x: usize = 0,
c_y: usize = 0,
event_publisher: *EventPublisher,
allocator: mem.Allocator,

pub fn init(allocator: mem.Allocator, event_publisher: *EventPublisher) Buffer {
    return .{
        .rows = std.ArrayList(UnicodeString).init(allocator),
        .event_publisher = event_publisher,
        .allocator = allocator,
    };
}

pub fn deinit(self: *const Buffer) void {
    for (self.rows.items) |row| row.deinit();
    self.rows.deinit();
}

pub fn setCursor(self: *Buffer, x: usize, y: usize) void {
    self.c_x = x;
    self.c_y = y;
}

pub fn moveForward(self: *Buffer) void {
    const row = self.getCurrentRow();
    if (self.c_x < row.getLen()) {
        self.c_x += 1;
    } else if (self.c_y < self.rows.items.len - 1) {
        self.c_y += 1;
        self.c_x = 0;
    }
}

pub fn moveBackward(self: *Buffer) void {
    if (self.c_x > 0) {
        self.c_x -= 1;
    } else if (self.c_y > 0) {
        self.c_y -= 1;
        self.c_x = self.getCurrentRow().getLen();
    }
}

pub fn moveToBeginningOfLine(self: *Buffer) void {
    self.c_x = 0;
}

pub fn moveToEndOfLine(self: *Buffer) void {
    self.c_x = self.getCurrentRow().getLen();
}

pub fn getCurrentRow(self: *const Buffer) *UnicodeString {
    return &self.rows.items[self.c_y];
}

pub fn insertChar(self: *Buffer, c: u21) !void {
    try self.getCurrentRow().insert(self.c_x, c);
    self.moveForward();
}

pub fn deleteChar(self: *Buffer) !void {
    if (self.c_x >= self.getCurrentRow().getLen()) {
        try self.joinLine();
        return;
    }
    try self.getCurrentRow().remove(self.c_x);
}

pub fn deleteBackwardChar(self: *Buffer) !void {
    self.moveBackward();
    try self.deleteChar();
}

pub fn joinLine(self: *Buffer) !void {
    if (self.c_y >= self.rows.items.len - 1) {
        return;
    }
    var next_row = self.rows.items[self.c_y + 1];
    try self.getCurrentRow().appendSlice(next_row.buffer.items);
    next_row.deinit();
    _ = self.rows.orderedRemove(self.c_y + 1);
}

pub fn killLine(self: *Buffer) !void {
    const row = self.getCurrentRow();
    if (self.c_x >= row.getLen()) {
        try self.deleteChar();
        return;
    }
    for (0..row.getLen() - self.c_x) |_| {
        try self.deleteChar();
    }
}

pub fn breakLine(self: *Buffer) !void {
    var new_row = try UnicodeString.init(self.allocator);
    errdefer new_row.deinit();
    if (self.c_x < self.getCurrentRow().getLen()) {
        for (0..self.getCurrentRow().getLen() - self.c_x) |_| {
            const r = self.getCurrentRow();
            try new_row.appendSlice(r.buffer.items[r.u8_index.items[self.c_x]..r.u8_index.items[self.c_x + 1]]);
            try self.deleteChar();
        }
    }
    try self.rows.insert(self.c_y + 1, new_row);
    self.moveForward();
}

pub fn notifyUpdate(self: *Buffer) !void {
    try self.event_publisher.publish(.{ .buffer_updated = .{ .from = .{ .x = 0, .y = 0 }, .to = .{ .x = 0, .y = 0 } } });
}

test "Buffer: moveForward" {
    var event_publisher = EventPublisher.init(testing.allocator);
    defer event_publisher.deinit();
    var buf = Buffer.init(testing.allocator, &event_publisher);
    defer buf.deinit();
    const lines = [_][]const u8{
        "ab",
        "cd",
        "",
    };
    for (lines) |line| {
        var l = try UnicodeString.init(testing.allocator);
        errdefer l.deinit();
        try l.appendSlice(line);
        try buf.rows.append(l);
    }

    try testing.expectFmt("0 0", "{} {}", .{ buf.c_x, buf.c_y });

    buf.moveForward();
    try testing.expectFmt("1 0", "{} {}", .{ buf.c_x, buf.c_y });

    buf.moveForward();
    try testing.expectFmt("2 0", "{} {}", .{ buf.c_x, buf.c_y });

    buf.moveForward();
    try testing.expectFmt("0 1", "{} {}", .{ buf.c_x, buf.c_y });

    buf.moveForward();
    try testing.expectFmt("1 1", "{} {}", .{ buf.c_x, buf.c_y });

    buf.moveForward();
    try testing.expectFmt("2 1", "{} {}", .{ buf.c_x, buf.c_y });

    buf.moveForward();
    try testing.expectFmt("0 2", "{} {}", .{ buf.c_x, buf.c_y });

    buf.moveForward();
    try testing.expectFmt("0 2", "{} {}", .{ buf.c_x, buf.c_y });
}
