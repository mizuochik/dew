const std = @import("std");
const mem = std.mem;
const testing = std.testing;
const dew = @import("../dew.zig");
const Editor = dew.Editor;
const Arrow = Editor.Arrow;

const Buffer = @This();

rows: std.ArrayList(dew.UnicodeString),
c_x: usize = 0,
c_y: usize = 0,
allocator: mem.Allocator,

pub fn init(allocator: mem.Allocator) Buffer {
    var rows = std.ArrayList(dew.UnicodeString).init(allocator);
    return .{
        .rows = rows,
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
    const row = self.getCurrentRow() orelse return;
    if (self.c_x < row.getLen()) {
        self.c_x += 1;
    } else if (self.c_y < self.rows.items.len) {
        self.c_y += 1;
        self.c_x = 0;
    }
}

pub fn getCurrentRow(self: *Buffer) ?*dew.UnicodeString {
    if (self.c_y >= self.rows.items.len) {
        return null;
    }
    return &self.rows.items[self.c_y];
}

test "Buffer: moveForward" {
    var buf = Buffer.init(testing.allocator);
    defer buf.deinit();
    const lines = [_][]const u8{
        "ab",
        "cd",
    };
    for (lines) |line| {
        var l = try dew.UnicodeString.init(testing.allocator);
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
