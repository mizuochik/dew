const std = @import("std");

const Position = @This();

x: usize,
y: usize,

pub fn format(self: Position, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
    try writer.print("({d}, {d})", .{ self.x, self.y });
}
