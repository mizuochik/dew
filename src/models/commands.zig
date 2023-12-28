const std = @import("std");

pub const OpenFile = @import("commands/OpenFile.zig");
pub const NewFile = @import("commands/NewFile.zig");
pub const SaveFile = @import("commands/SaveFile.zig");

test {
    _ = std.testing.refAllDecls(@This());
}
