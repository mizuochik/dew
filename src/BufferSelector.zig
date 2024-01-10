const std = @import("std");
const models = @import("models.zig");
const Buffer = @import("Buffer.zig");
const Editor = @import("Editor.zig");

const BufferSelector = @This();

allocator: std.mem.Allocator,
file_buffers: std.StringHashMap(*Buffer),
editor: *Editor,

pub fn init(allocator: std.mem.Allocator, editor: *Editor) !BufferSelector {
    var file_buffer = try Buffer.init(allocator);
    errdefer file_buffer.deinit();
    if (!editor.client.hasCursor("default")) {
        try editor.client.addCursor("default", file_buffer);
    }
    errdefer editor.client.removeCursor("default");

    var file_buffers = std.StringHashMap(*Buffer).init(allocator);
    errdefer file_buffers.deinit();

    const default_key = try std.fmt.allocPrint(allocator, "default", .{});
    errdefer allocator.free(default_key);
    try file_buffers.put(default_key, file_buffer);

    try editor.client.setEditingFile("default", file_buffer);

    return .{
        .allocator = allocator,
        .file_buffers = file_buffers,
        .editor = editor,
    };
}

pub fn deinit(self: *BufferSelector) void {
    var it = self.file_buffers.iterator();
    while (it.next()) |entry| {
        self.allocator.free(entry.key_ptr.*); // second
        entry.value_ptr.*.deinit();
    }
    self.file_buffers.deinit();
}

pub fn getCommandLine(self: *BufferSelector) *Buffer {
    return self.editor.client.command_line;
}

pub fn getCurrentFileBuffer(self: *const BufferSelector) *Buffer {
    return self.file_buffers.get(self.editor.client.current_file.?).?;
}

pub fn getCurrentBuffer(self: *const BufferSelector) *Buffer {
    if (self.editor.client.is_command_line_active) {
        return self.editor.client.command_line;
    }
    return self.getCurrentFileBuffer();
}

pub fn addFileBuffer(self: *BufferSelector, file_path: []const u8, buffer: *Buffer) !void {
    try self.file_buffers.put(file_path, buffer);
}

pub fn openFileBuffer(self: *BufferSelector, name: []const u8) !void {
    if (self.file_buffers.getEntry(name)) |entry| {
        try self.editor.client.setEditingFile(entry.key_ptr.*, entry.value_ptr.*);
        return;
    }
    var buffer = try Buffer.init(self.allocator);
    errdefer buffer.deinit();
    try self.editor.client.addCursor(name, buffer);
    errdefer self.editor.client.removeCursor(name);

    buffer.openFile(name) catch |err| switch (err) {
        std.fs.File.OpenError.FileNotFound => {}, // Open as an empty file
        else => return err,
    };
    const key = try self.allocator.dupe(u8, name);
    errdefer self.allocator.free(key);
    try self.file_buffers.put(key, buffer);
    errdefer _ = self.file_buffers.remove(key);
    try self.editor.client.setEditingFile(key, buffer);
}

pub fn saveFileBuffer(self: *BufferSelector, name: []const u8) !void {
    const buffer = try self.getCurrentFileBuffer().clone();
    errdefer buffer.deinit();
    const key = try self.allocator.dupe(u8, name);
    errdefer self.allocator.free(key);
    const result = try self.file_buffers.getOrPut(key);
    errdefer if (!result.found_existing) {
        _ = self.file_buffers.remove(key);
    };
    try buffer.saveFile(name);
    if (result.found_existing) {
        self.allocator.free(key);
        result.value_ptr.*.deinit();
    }
    result.value_ptr.* = buffer;
    try self.editor.client.setEditingFile(name, buffer);
}

test {
    std.testing.refAllDecls(@This());
}
