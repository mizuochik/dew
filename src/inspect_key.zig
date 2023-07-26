const std = @import("std");
const io = std.io;

pub fn main() !void {
    while (true) {
        const b = try io.getStdIn().reader().readByte();
        std.debug.print("key = 0x{x}\n", .{b});
    }
}
