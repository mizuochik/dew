const std = @import("std");
const event = @import("../event.zig");
const models = @import("../models.zig");
const Buffer = @import("Buffer.zig");

const BufferSelector = @This();

allocator: std.mem.Allocator,
command_buffer: *Buffer,
is_command_buffer_active: bool,
current_file_buffer: []const u8,
file_buffers: std.StringHashMap(*Buffer),
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

    var file_buffers = std.StringHashMap(*Buffer).init(allocator);
    errdefer file_buffers.deinit();
    try file_buffers.put("default", file_buffer);

    return .{
        .allocator = allocator,
        .command_buffer = command_buffer,
        .current_file_buffer = "default",
        .is_command_buffer_active = false,
        .file_buffers = file_buffers,
        .event_publisher = event_publisher,
    };
}

pub fn deinit(self: *BufferSelector) void {
    self.command_buffer.deinit();
    self.allocator.destroy(self.command_buffer);
    var it = self.file_buffers.valueIterator();
    while (it.next()) |buf| {
        buf.*.deinit();
        self.allocator.destroy(buf.*);
    }
    self.file_buffers.deinit();
}

pub fn toggleCommandBuffer(self: *BufferSelector) !void {
    if (self.is_command_buffer_active) {
        try self.command_buffer.clear();
        self.is_command_buffer_active = false;
        try self.event_publisher.publish(.command_buffer_closed);
    } else {
        self.is_command_buffer_active = true;
        try self.event_publisher.publish(.command_buffer_opened);
    }
}

pub fn getCurrentFileBuffer(self: *const BufferSelector) *Buffer {
    return self.file_buffers.get(self.current_file_buffer).?;
}

pub fn getCurrentBuffer(self: *const BufferSelector) *Buffer {
    if (self.is_command_buffer_active) {
        return self.command_buffer;
    }
    return self.getCurrentFileBuffer();
}

test {
    std.testing.refAllDecls(@This());
}
