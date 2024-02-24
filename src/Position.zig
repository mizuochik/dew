const std = @import("std");
const parser = @import("./parser.zig");

x: usize,
y: usize,

pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
    try writer.print("{d}:{d}", .{ self.y + 1, self.x + 1 });
}

pub fn parse(allocator: std.mem.Allocator, input: []const u8) !@This() {
    var state: parser.State = .{
        .input = input,
        .allocator = allocator,
    };
    defer state.deinit();
    const line: usize = @intCast(try parser.number(&state));
    _ = try parser.character(&state, ':');
    const character: usize = @intCast(try parser.number(&state));
    return .{
        .x = line - 1,
        .y = character - 1,
    };
}

test "parse" {
    const pos = try parse(std.testing.allocator, "5:10");
    try std.testing.expectFmt("5:10", "{}", .{pos});
}
