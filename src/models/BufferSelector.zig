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
event_publisher: *event.Publisher(models.Event),

pub fn init(allocator: std.mem.Allocator, event_publisher: *event.Publisher(models.Event)) !BufferSelector {
    var file_buffer = try Buffer.init(allocator, event_publisher, .file);
    errdefer file_buffer.deinit();
    try file_buffer.addCursor();

    var command_buffer = try Buffer.init(allocator, event_publisher, .command);
    errdefer command_buffer.deinit();
    try command_buffer.addCursor();

    var file_buffers = std.StringHashMap(*Buffer).init(allocator);
    errdefer file_buffers.deinit();

    const default_key = try std.fmt.allocPrint(allocator, "default", .{});
    errdefer allocator.free(default_key);
    try file_buffers.put(default_key, file_buffer);

    return .{
        .allocator = allocator,
        .command_buffer = command_buffer,
        .current_file_buffer = default_key,
        .is_command_buffer_active = false,
        .file_buffers = file_buffers,
        .event_publisher = event_publisher,
    };
}

pub fn deinit(self: *BufferSelector) void {
    self.command_buffer.deinit();
    var it = self.file_buffers.iterator();
    while (it.next()) |entry| {
        self.allocator.free(entry.key_ptr.*); // second
        entry.value_ptr.*.deinit();
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

pub fn openFileBuffer_(self: *BufferSelector, name: []const u8) !void {
    const entry = self.file_buffers.getEntry(name) orelse return error.FileNotFound;
    self.current_file_buffer = entry.key_ptr.*;
    try self.event_publisher.publish(.file_buffer_changed);
}

pub fn addFileBuffer(self: *BufferSelector, file_path: []const u8, buffer: *Buffer) !void {
    try self.file_buffers.put(file_path, buffer);
}

pub fn openFileBuffer(self: *BufferSelector, name: []const u8) !void {
    if (self.file_buffers.getKey(name)) |key| {
        self.current_file_buffer = key;
        try self.event_publisher.publish(.file_buffer_changed);
        return;
    }
    var buffer = try Buffer.init(self.allocator, self.event_publisher, .file);
    errdefer buffer.deinit();
    try buffer.addCursor();
    buffer.openFile(name) catch |err| switch (err) {
        std.fs.File.OpenError.FileNotFound => {}, // Open as an empty file
        else => return err,
    };
    const key = try self.allocator.dupe(u8, name);
    errdefer self.allocator.free(key);
    try self.file_buffers.put(key, buffer);
    errdefer _ = self.file_buffers.remove(key);
    self.current_file_buffer = key;
    try self.event_publisher.publish(.file_buffer_changed);
}

pub fn saveFileBuffer(self: *BufferSelector, name: []const u8) !void {
    const buffer = try self.getCurrentFileBuffer().clone();
    errdefer buffer.deinit();
    if (self.file_buffers.getEntry(name)) |buffer_entry| {
        buffer_entry.value_ptr.*.deinit();
        buffer_entry.value_ptr.* = buffer;
        try buffer.saveFile(name);
        return;
    }
    const key = try self.allocator.dupe(u8, name);
    errdefer self.allocator.free(key);
    try self.file_buffers.put(key, buffer);
    try buffer.saveFile(name);
}

test {
    std.testing.refAllDecls(@This());
}
