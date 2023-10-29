const std = @import("std");

pub const BufferView = @import("view/BufferView.zig");
pub const StatusBarView = @import("view/StatusBarView.zig");

pub const Event = union(enum) {
    buffer_view_updated,
    command_buffer_view_updated,
    status_bar_view_updated,

    pub fn deinit(_: *const Event) void {}
};

test {
    std.testing.refAllDecls(@This());
}
