const dew = @import("../../dew.zig");
const models = dew.models;
const std = @import("std");
const testing = std.testing;

const Self = @This();

file_buffer: *models.Buffer,
command_buffer: *models.Buffer,
current_buffer: *models.Buffer,

pub fn init(file_buffer: *models.Buffer, command_buffer: *models.Buffer) Self {
    return .{
        .file_buffer = file_buffer,
        .command_buffer = command_buffer,
        .current_buffer = file_buffer,
    };
}

pub fn deinit(_: *const Self) void {}

pub fn toggleCommandBuffer(self: *Self) !void {
    if (self.command_buffer.is_active) {
        self.current_buffer = self.file_buffer;
        try self.file_buffer.activate();
        try self.command_buffer.deactivate();
    } else {
        self.current_buffer = self.command_buffer;
        try self.file_buffer.deactivate();
        try self.command_buffer.activate();
    }
}

test {
    testing.refAllDecls(@This());
}
