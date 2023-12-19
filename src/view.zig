const std = @import("std");

pub const BufferView = @import("view/BufferView.zig");
pub const StatusBarView = @import("view/StatusBarView.zig");
pub const DisplaySize = @import("view/DisplaySize.zig");

pub const Event = union(enum) {
    buffer_view_updated,
    command_buffer_view_updated,
    status_bar_view_updated,
    screen_size_changed: ScreenSize,

    pub fn deinit(_: *const Event) void {}
};

pub const ScreenSize = struct {
    width: usize,
    height: usize,
};

test {
    std.testing.refAllDecls(@This());
}