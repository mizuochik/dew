const std = @import("std");

pub const OpenFile = @import("commands/OpenFile.zig");
pub const NewFile = @import("commands/NewFile.zig");

test {
    _ = std.testing.refAllDecls(@This());
}
