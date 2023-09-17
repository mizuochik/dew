const dew = @import("../../dew.zig");
const models = dew.models;
const std = @import("std");
const testing = std.testing;

const Self = @This();

file_buffer: *models.Buffer,
command_buffer: *models.Buffer,
current_buffer: *models.Buffer,
event_publisher: *const dew.event.Publisher(models.Event),

pub fn init(file_buffer: *models.Buffer, command_buffer: *models.Buffer, event_publisher: *const dew.event.Publisher(models.Event)) Self {
    return .{
        .file_buffer = file_buffer,
        .command_buffer = command_buffer,
        .event_publisher = event_publisher,
        .current_buffer = file_buffer,
    };
}

pub fn deinit(_: *const Self) void {}

pub fn openCommandBuffer(self: *Self) !void {
    self.current_buffer = self.command_buffer;
    try self.event_publisher.publish(.command_buffer_opened);
}

pub fn closeCommandBuffer(self: *Self) !void {
    self.current_buffer = self.file_buffer;
    try self.event_publisher.publish(.command_buffer_closed);
}

test {
    testing.refAllDecls(@This());
}
