const std = @import("std");

pub const Editor = @import("dew/Editor.zig");
pub const c = @import("dew/c.zig");

test {
    std.testing.refAllDecls(@This());
}
