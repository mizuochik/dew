const dew = @import("../../dew.zig");
const models = dew.models;
const std = @import("std");
const testing = std.testing;

const BufferSelector = @This();

file_buffer: *models.Buffer,
command_buffer: *models.Buffer,
current_buffer: *models.Buffer,
event_publisher: *const dew.event.Publisher(models.Event),

pub fn init(file_buffer: *models.Buffer, command_buffer: *models.Buffer, event_publisher: *const dew.event.Publisher(models.Event)) BufferSelector {
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
    testing.refAllDecls(@This());
}
