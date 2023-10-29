const std = @import("std");

pub fn main() !void {
    while (true) {
        const b = try std.io.getStdIn().reader().readByte();
        std.debug.print("key = 0x{x}\n", .{b});
    }
}
