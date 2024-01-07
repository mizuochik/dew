const std = @import("std");
const Position = @import("Position.zig");
const UnicodeString = @import("UnicodeString.zig");

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
