const std = @import("std");
const Text = @import("Text.zig");
const Editor = @import("Editor.zig");

allocator: std.mem.Allocator,
file_buffers: std.StringHashMap(*Text),
editor: *Editor,

pub fn init(allocator: std.mem.Allocator, editor: *Editor) !@This() {
    var file_text = try Text.init(allocator);
    errdefer file_text.deinit();

    var file_texts = std.StringHashMap(*Text).init(allocator);
    errdefer file_texts.deinit();

    const default_key = try std.fmt.allocPrint(allocator, "default", .{});
    errdefer allocator.free(default_key);
    try file_texts.put(default_key, file_text);

    try editor.client.putFileRef("default", file_text);

    return .{
        .allocator = allocator,
        .file_buffers = file_texts,
        .editor = editor,
    };
}

pub fn deinit(self: *@This()) void {
    var it = self.file_buffers.iterator();
    while (it.next()) |entry| {
        self.allocator.free(entry.key_ptr.*); // second
        entry.value_ptr.*.deinit();
    }
    self.file_buffers.deinit();
}

pub fn openFileBuffer(self: *@This(), name: []const u8) !void {
    if (self.file_buffers.getEntry(name)) |entry| {
        try self.editor.client.putFileRef(entry.key_ptr.*, entry.value_ptr.*);
        return;
    }
    var text = try Text.init(self.allocator);
    errdefer text.deinit();
    text.openFile(name) catch |err| switch (err) {
        std.fs.File.OpenError.FileNotFound => {}, // Open as an empty file
        else => return err,
    };
    const key = try self.allocator.dupe(u8, name);
    errdefer self.allocator.free(key);
    try self.file_buffers.put(key, text);
    errdefer _ = self.file_buffers.remove(key);
    try self.editor.client.putFileRef(key, text);
}

pub fn saveFileBuffer(self: *@This(), name: []const u8) !void {
    const text = try self.editor.client.getActiveFile().?.selection.text.clone();
    errdefer text.deinit();
    const key = try self.allocator.dupe(u8, name);
    errdefer self.allocator.free(key);
    const result = try self.file_buffers.getOrPut(key);
    errdefer if (!result.found_existing) {
        _ = self.file_buffers.remove(key);
    };
    try text.saveFile(name);
    if (result.found_existing) {
        self.allocator.free(key);
        result.value_ptr.*.deinit();
    }
    result.value_ptr.* = text;
    try self.editor.client.putFileRef(name, text);
}

test {
    std.testing.refAllDecls(@This());
}
