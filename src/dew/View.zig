const std = @import("std");
const testing = std.testing;

pub const BufferView = @import("view/BufferView.zig");

test {
    testing.refAllDecls(@This());
}
