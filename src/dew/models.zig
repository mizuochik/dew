const std = @import("std");
const testing = std.testing;

pub const Buffer = @import("models/Buffer.zig");
pub const Position = @import("models/Position.zig");
pub const UnicodeString = @import("models/UnicodeString.zig");
pub const StatusBar = @import("models/StatusBar.zig");

pub const Key = union(enum) {
    plain: u21,
    ctrl: u8,
    meta: u8,
    arrow: Arrow,
    del,
};

pub const Arrow = enum {
    up,
    down,
    right,
    left,
};

pub const Event = union(enum) {
    buffer_updated: struct {
        from: Position,
        to: Position,
    },
    status_bar_updated,
    screen_size_changed: ScreenSize,
};

pub const ScreenSize = struct {
    width: usize,
    height: usize,
};

test {
    testing.refAllDecls(@This());
}
