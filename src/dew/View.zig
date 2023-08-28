const std = @import("std");
const testing = std.testing;

pub const BufferView = @import("view/BufferView.zig");
pub const StatusBarView = @import("view/StatusBarView.zig");

pub const Event = union(enum) {
    buffer_view_updated,
};

test {
    testing.refAllDecls(@This());
}
