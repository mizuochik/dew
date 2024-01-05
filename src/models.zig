const std = @import("std");

pub const debug = @import("models/debug.zig");
pub const commands = @import("models/commands.zig");
pub const Buffer = @import("models/Buffer.zig");
pub const Position = @import("models/Position.zig");
pub const UnicodeString = @import("models/UnicodeString.zig");
pub const StatusMessage = @import("models/StatusMessage.zig");
pub const BufferSelector = @import("models/BufferSelector.zig");
pub const Cursor = @import("models/Cursor.zig");
pub const Command = @import("models/Command.zig");
pub const CommandEvaluator = @import("models/CommandEvaluator.zig");
pub const CommandLineParser = @import("models/CommandLineParser.zig");

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

test {
    std.testing.refAllDecls(@This());
}
