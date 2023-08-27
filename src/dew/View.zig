const std = @import("std");
const testing = std.testing;

pub const BufferView = @import("view/BufferView.zig");
pub const StatusBarView = @import("view/StatusBarView.zig");

test {
    testing.refAllDecls(@This());
}
