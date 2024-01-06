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

pub const Event = union(enum) {
    buffer_updated: struct {
        from: Position,
        to: Position,
    },
    status_message_updated,
    file_buffer_changed,
    command_buffer_opened,
    command_buffer_closed,
    command_executed: UnicodeString,
    cursor_moved,

    pub fn deinit(self: Event) void {
        switch (self) {
            Event.command_executed => |s| {
                s.deinit();
            },
            else => {},
        }
    }
};
