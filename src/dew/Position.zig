const std = @import("std");
const fmt = std.fmt;

const Position = @This();

x: usize,
y: usize,

pub fn format(self: Position, comptime _: []const u8, _: fmt.FormatOptions, writer: anytype) !void {
    try writer.print("({d}, {d})", .{ self.x, self.y });
}
