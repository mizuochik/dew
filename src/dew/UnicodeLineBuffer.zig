const std = @import("std");
const mem = std.mem;
const unicode = std.unicode;
const testing = std.testing;
const UnicodeLineBuffer = @This();

buffer: std.ArrayList(u8),
u8_index: std.ArrayList(usize),
cursor_index: std.ArrayList(usize),

pub fn init(allocator: mem.Allocator) !UnicodeLineBuffer {
    var buf = UnicodeLineBuffer{
        .buffer = std.ArrayList(u8).init(allocator),
        .u8_index = std.ArrayList(usize).init(allocator),
        .cursor_index = std.ArrayList(usize).init(allocator),
    };
    try buf.refreshIndex();
    return buf;
}

pub fn deinit(self: *const UnicodeLineBuffer) void {
    self.buffer.deinit();
    self.u8_index.deinit();
    self.cursor_index.deinit();
}

pub fn insert(self: *UnicodeLineBuffer, i: usize, c: u21) !void {
    var enc: [4]u8 = undefined;
    const to = try unicode.utf8Encode(c, &enc);
    try self.buffer.insertSlice(self.u8_index.items[i], enc[0..to]);
    try self.refreshIndex();
}

pub fn appendSlice(self: *UnicodeLineBuffer, s: []const u8) !void {
    try self.buffer.appendSlice(s);
    try self.refreshIndex();
}

pub fn remove(self: *UnicodeLineBuffer, i: usize) !void {
    const from = self.u8_index.items[i];
    const to = self.u8_index.items[i + 1];
    for (from..to) |_| {
        _ = self.buffer.orderedRemove(from);
    }
    try self.refreshIndex();
}

fn refreshIndex(self: *UnicodeLineBuffer) !void {
    try self.refreshU8Index();
    try self.refreshCursorIndex();
}

fn refreshU8Index(self: *UnicodeLineBuffer) !void {
    var new_u8_index = std.ArrayList(usize).init(self.buffer.allocator);
    errdefer new_u8_index.deinit();

    const view = try unicode.Utf8View.init(self.buffer.items);
    var it = view.iterator();

    try new_u8_index.append(it.i);
    while (it.nextCodepoint()) |_| {
        try new_u8_index.append(it.i);
    }

    self.u8_index.deinit();
    self.u8_index = new_u8_index;
}

fn refreshCursorIndex(self: *UnicodeLineBuffer) !void {
    var new_cursor_index = std.ArrayList(usize).init(self.buffer.allocator);
    errdefer new_cursor_index.deinit();
    var j: usize = 0;
    try new_cursor_index.append(j);
    for (0..self.u8_index.items.len - 1) |i| {
        j += if (self.u8_index.items[i + 1] - self.u8_index.items[i] > 1) 2 else 1;
        try new_cursor_index.append(j);
    }
    self.cursor_index.deinit();
    self.cursor_index = new_cursor_index;
}

test "UnicodeLineBuffer: insert" {
    var lb = try UnicodeLineBuffer.init(testing.allocator);
    defer lb.deinit();

    try lb.insert(0, '世');
    try lb.insert(1, '界');

    try testing.expectFmt("世界", "{s}", .{lb.buffer.items});
    try testing.expectFmt("{ 0, 3, 6 }", "{any}", .{lb.u8_index.items});
    try testing.expectFmt("{ 0, 2, 4 }", "{any}", .{lb.cursor_index.items});
}

test "UnicodeLineBuffer: remove" {
    var lb = try UnicodeLineBuffer.init(testing.allocator);
    defer lb.deinit();
    try lb.appendSlice("こんにちは");
    std.debug.assert(mem.eql(u8, "こんにちは", lb.buffer.items));

    try lb.remove(2);

    try testing.expectFmt("こんちは", "{s}", .{lb.buffer.items});
    try testing.expectFmt("{ 0, 3, 6, 9, 12 }", "{any}", .{lb.u8_index.items});
    try testing.expectFmt("{ 0, 2, 4, 6, 8 }", "{any}", .{lb.cursor_index.items});
}
