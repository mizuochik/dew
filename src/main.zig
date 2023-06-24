const std = @import("std");
const os = std.os;
const io = std.io;

pub fn main() !void {
    var buf = [_]u8{0} ** 32;
    while (io.getStdIn().read(&buf)) |_| {
        if (buf[0] == 'q')
            break;
    } else |err| {
        return err;
    }
}
