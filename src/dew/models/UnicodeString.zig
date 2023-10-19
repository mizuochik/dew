const std = @import("std");
const mem = std.mem;
const unicode = std.unicode;
const testing = std.testing;
const UnicodeString = @This();

buffer: std.ArrayList(u8),
u8_index: std.ArrayList(usize),
width_index: std.ArrayList(usize),

pub fn init(allocator: mem.Allocator) !UnicodeString {
    var buf = UnicodeString{
        .buffer = std.ArrayList(u8).init(allocator),
        .u8_index = std.ArrayList(usize).init(allocator),
        .width_index = std.ArrayList(usize).init(allocator),
    };
    try buf.refreshIndex();
    return buf;
}

pub fn deinit(self: *const UnicodeString) void {
    self.buffer.deinit();
    self.u8_index.deinit();
    self.width_index.deinit();
}

pub fn insert(self: *UnicodeString, i: usize, c: u21) !void {
    var enc: [4]u8 = undefined;
    const to = try unicode.utf8Encode(c, &enc);
    try self.buffer.insertSlice(self.u8_index.items[i], enc[0..to]);
    try self.refreshIndex();
}

pub fn appendSlice(self: *UnicodeString, s: []const u8) !void {
    try self.buffer.appendSlice(s);
    try self.refreshIndex();
}

pub fn remove(self: *UnicodeString, i: usize) !void {
    const from = self.u8_index.items[i];
    const to = self.u8_index.items[i + 1];
    for (from..to) |_| {
        _ = self.buffer.orderedRemove(from);
    }
    try self.refreshIndex();
}

pub fn clear(self: *UnicodeString) !void {
    const allocator = self.buffer.allocator;
    self.buffer.clearAndFree();
    self.buffer = std.ArrayList(u8).init(allocator);
    try self.refreshIndex();
}

pub fn sliceAsRaw(self: *const UnicodeString, i: usize, j: usize) []u8 {
    return self.buffer.items[self.u8_index.items[i]..self.u8_index.items[j]];
}

fn refreshIndex(self: *UnicodeString) !void {
    try self.refreshU8Index();
    try self.refreshWidthIndex();
}

fn refreshU8Index(self: *UnicodeString) !void {
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

fn refreshWidthIndex(self: *UnicodeString) !void {
    var new_width_index = std.ArrayList(usize).init(self.buffer.allocator);
    errdefer new_width_index.deinit();
    var j: usize = 0;
    try new_width_index.append(j);
    for (0..self.u8_index.items.len - 1) |i| {
        j += if (self.u8_index.items[i + 1] - self.u8_index.items[i] > 1) 2 else 1;
        try new_width_index.append(j);
    }
    self.width_index.deinit();
    self.width_index = new_width_index;
}

pub fn getLen(self: *const UnicodeString) usize {
    return self.u8_index.items.len - 1;
}

pub fn getWidth(self: *const UnicodeString) usize {
    return self.width_index.items[self.width_index.items.len - 1];
}

test "UnicodeString: insert" {
    var lb = try UnicodeString.init(testing.allocator);
    defer lb.deinit();

    try lb.insert(0, '世');
    try lb.insert(1, '界');

    try testing.expectFmt("世界", "{s}", .{lb.buffer.items});
    try testing.expectFmt("{ 0, 3, 6 }", "{any}", .{lb.u8_index.items});
    try testing.expectFmt("{ 0, 2, 4 }", "{any}", .{lb.width_index.items});
    try testing.expectEqual(@as(usize, 2), lb.getLen());
    try testing.expectEqual(@as(usize, 4), lb.getWidth());
}

test "UnicodeString: remove" {
    var lb = try UnicodeString.init(testing.allocator);
    defer lb.deinit();
    try lb.appendSlice("こんにちは");
    std.debug.assert(mem.eql(u8, "こんにちは", lb.buffer.items));

    try lb.remove(2);

    try testing.expectFmt("こんちは", "{s}", .{lb.buffer.items});
    try testing.expectFmt("{ 0, 3, 6, 9, 12 }", "{any}", .{lb.u8_index.items});
    try testing.expectFmt("{ 0, 2, 4, 6, 8 }", "{any}", .{lb.width_index.items});
    try testing.expectEqual(@as(usize, 4), lb.getLen());
    try testing.expectEqual(@as(usize, 8), lb.getWidth());
}

test "UnicodeString: clear" {
    var s = try UnicodeString.init(testing.allocator);
    defer s.deinit();
    try s.appendSlice("foobar");
    try s.clear();
    try testing.expectEqual(@as(usize, 0), s.buffer.items.len);
}
