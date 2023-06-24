const std = @import("std");
const os = std.os;
const io = std.io;

pub fn main() !void {
    var buf = [_]u8{0} ** 32;

    while (try io.getStdIn().read(&buf) == 1) {}
}
