const std = @import("std");
const mem = std.mem;
const unicode = std.unicode;
const testing = std.testing;
const UnicodeLineBuffer = @This();

buffer: std.ArrayList(u8),
u8_index: std.ArrayList(usize),

pub fn init(allocator: mem.Allocator) !UnicodeLineBuffer {
    var buf = UnicodeLineBuffer{
        .buffer = std.ArrayList(u8).init(allocator),
        .u8_index = std.ArrayList(usize).init(allocator),
    };
    try buf.refreshCodePoints();
    return buf;
}

pub fn deinit(self: *UnicodeLineBuffer) void {
    self.buffer.deinit();
    self.u8_index.deinit();
}

pub fn insert(self: *UnicodeLineBuffer, i: usize, c: u21) !void {
    var enc: [4]u8 = undefined;
    const to = try unicode.utf8Encode(c, &enc);
    try self.buffer.insertSlice(self.u8_index.items[i], enc[0..to]);
    try self.refreshCodePoints();
}

pub fn remove(self: *UnicodeLineBuffer, i: usize) !void {
    const from = self.u8_index.items[i];
    const to = self.u8_index.items[i + 1];
    for (from..to) |_| {
        _ = self.buffer.orderedRemove(from);
    }
    try self.refreshCodePoints();
}

pub fn refreshCodePoints(self: *UnicodeLineBuffer) !void {
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

test "UnicodeLineBuffer: insert" {
    var lb = try UnicodeLineBuffer.init(testing.allocator);
    defer lb.deinit();

    try lb.insert(0, '世');
    try lb.insert(1, '界');

    try testing.expectFmt("世界", "{s}", .{lb.buffer.items});
    const cps: []const usize = &[_]usize{ 0, 3, 6 };
    try testing.expectEqualDeep(cps, lb.u8_index.items);
}

test "UnicodeLineBuffer: remove" {
    var lb = try UnicodeLineBuffer.init(testing.allocator);
    defer lb.deinit();
    try lb.insert(0, 'こ');
    try lb.insert(1, 'ん');
    try lb.insert(2, 'に');
    try lb.insert(3, 'ち');
    try lb.insert(4, 'は');
    std.debug.assert(mem.eql(u8, "こんにちは", lb.buffer.items));

    try lb.remove(2);

    try testing.expectFmt("こんちは", "{s}", .{lb.buffer.items});
    try testing.expectFmt("{ 0, 3, 6, 9, 12 }", "{any}", .{lb.u8_index.items});
}
