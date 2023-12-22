const std = @import("std");
const event = @import("../event.zig");
const models = @import("../models.zig");
const Buffer = @import("Buffer.zig");

const BufferSelector = @This();

allocator: std.mem.Allocator,
file_buffer: *Buffer,
command_buffer: *Buffer,
current_buffer: *Buffer,
event_publisher: *const event.Publisher(models.Event),

pub fn init(allocator: std.mem.Allocator, event_publisher: *event.Publisher(models.Event)) !BufferSelector {
    var file_buffer = try allocator.create(Buffer);
    errdefer allocator.destroy(file_buffer);
    file_buffer.* = try Buffer.init(allocator, event_publisher, .file);
    errdefer file_buffer.deinit();
    try file_buffer.addCursor();

    var command_buffer = try allocator.create(Buffer);
    errdefer allocator.destroy(command_buffer);
    command_buffer.* = try Buffer.init(allocator, event_publisher, .command);
    errdefer command_buffer.deinit();
    try command_buffer.addCursor();

    return .{
        .allocator = allocator,
        .file_buffer = file_buffer,
        .command_buffer = command_buffer,
        .event_publisher = event_publisher,
        .current_buffer = file_buffer,
    };
}

pub fn deinit(self: *const BufferSelector) void {
    self.file_buffer.deinit();
    self.allocator.destroy(self.file_buffer);
    self.command_buffer.deinit();
    self.allocator.destroy(self.command_buffer);
}

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
