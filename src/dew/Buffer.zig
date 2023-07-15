const std = @import("std");
const mem = std.mem;
const dew = @import("../dew.zig");

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
    for (self.rows) |row| row.deinit();
    self.rows.deinit();
}
