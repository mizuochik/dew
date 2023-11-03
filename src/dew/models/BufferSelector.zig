const dew = @import("../../dew.zig");
const std = @import("std");

const BufferSelector = @This();

file_buffer: *dew.models.Buffer,
command_buffer: *dew.models.Buffer,
current_buffer: *dew.models.Buffer,
event_publisher: *const dew.event.Publisher(dew.models.Event),

pub fn init(file_buffer: *dew.models.Buffer, command_buffer: *dew.models.Buffer, event_publisher: *const dew.event.Publisher(dew.models.Event)) BufferSelector {
    return .{
        .file_buffer = file_buffer,
        .command_buffer = command_buffer,
        .event_publisher = event_publisher,
        .current_buffer = file_buffer,
    };
}

pub fn deinit(_: *const BufferSelector) void {}

pub fn toggleCommandBuffer(self: *BufferSelector) !void {
    const is_active = self.current_buffer == self.command_buffer;
    if (is_active) {
        for (self.command_buffer.cursors.items) |*cursor| {
            try cursor.setPosition(.{ .x = 0, .y = 0 });
        }
        try self.command_buffer.clear();
        self.current_buffer = self.file_buffer;
        try self.event_publisher.publish(.command_buffer_closed);
    } else {
        self.current_buffer = self.command_buffer;
        try self.event_publisher.publish(.command_buffer_opened);
    }
}

test {
    std.testing.refAllDecls(@This());
}
