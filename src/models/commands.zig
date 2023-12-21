const std = @import("std");

pub const OpenFile = @import("commands/OpenFile.zig");

test {
    _ = std.testing.refAllDecls(@This());
}
