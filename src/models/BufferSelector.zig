const std = @import("std");
const event = @import("../event.zig");
const models = @import("../models.zig");
const Buffer = @import("Buffer.zig");

const BufferSelector = @This();

file_buffer: *Buffer,
command_buffer: *Buffer,
current_buffer: *Buffer,
event_publisher: *const event.Publisher(models.Event),

pub fn init(file_buffer: *models.Buffer, command_buffer: *models.Buffer, event_publisher: *const event.Publisher(models.Event)) BufferSelector {
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
