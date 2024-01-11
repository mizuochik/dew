const std = @import("std");
const Buffer = @import("Buffer.zig");
const Cursor = @import("Cursor.zig");
const Status = @import("Status.zig");

pub const EditingText = struct {
    text: *Buffer,
    cursor: Cursor,
    y_scroll: usize,
};

current_file: ?[]const u8 = null,
cursors: std.StringHashMap(Cursor),
command_cursor: Cursor,
scroll_positions: std.StringHashMap(usize),
command_line: *Buffer,
status: Status,
editing_files: std.StringHashMap(EditingText),
active_cursor: ?*Cursor = null,
active_text: ?*EditingText = null,
allocator: std.mem.Allocator,
is_command_line_active: bool = false,
command_line_: EditingText,

pub fn init(allocator: std.mem.Allocator) !@This() {
    var command_line = try Buffer.init(allocator);
    errdefer command_line.deinit();
    const command_cursor = .{
        .buffer = command_line,
        .x = 0,
        .y = 0,
    };
    var st = try Status.init(allocator);
    errdefer st.deinit();
    const editing_files = std.StringHashMap(EditingText).init(allocator);
    errdefer editing_files.deinit();
    return .{
        .cursors = std.StringHashMap(Cursor).init(allocator),
        .command_cursor = command_cursor,
        .scroll_positions = std.StringHashMap(usize).init(allocator),
        .command_line = command_line,
        .editing_files = editing_files,
        .status = st,
        .allocator = allocator,
        .command_line_ = .{
            .text = command_line,
            .cursor = .{
                .buffer = command_line,
                .x = 0,
                .y = 0,
            },
            .y_scroll = 0,
        },
    };
}

pub fn deinit(self: *@This()) void {
    var cursors_keys = self.cursors.keyIterator();
    while (cursors_keys.next()) |key| self.allocator.free(key.*);
    self.cursors.deinit();
    self.command_line.deinit();
    self.status.deinit();
    self.scroll_positions.deinit();
    var editing_file_keys = self.editing_files.keyIterator();
    while (editing_file_keys.next()) |key| self.allocator.free(key.*);
    self.editing_files.deinit();
}

pub fn hasCursor(self: *const @This(), file_name: []const u8) bool {
    return self.cursors.contains(file_name);
}

pub fn addCursor(self: *@This(), file_name: []const u8, buffer: *Buffer) !void {
    const key = try self.allocator.dupe(u8, file_name);
    errdefer self.allocator.free(key);
    try self.cursors.putNoClobber(key, .{
        .buffer = buffer,
        .x = 0,
        .y = 0,
    });
}

pub fn removeCursor(self: *@This(), file_name: []const u8) void {
    if (self.cursors.fetchRemove(file_name)) |kv| {
        self.allocator.free(kv.key);
    }
}

pub fn getActiveCursor(self: *@This()) *Cursor {
    if (self.is_command_line_active) {
        return &self.command_cursor;
    }
    return self.cursors.getPtr(self.current_file.?) orelse unreachable;
}

pub fn toggleCommandLine(self: *@This()) !void {
    if (self.is_command_line_active) {
        try self.command_line.clear();
        self.command_cursor.x = 0;
        self.is_command_line_active = false;
        self.active_text = self.getActiveFile();
    } else {
        self.is_command_line_active = true;
        self.active_text = &self.command_line_;
    }
}

pub fn getActiveText(self: *@This()) ?*Buffer {
    if (self.active_cursor) |cursor| {
        return cursor.buffer;
    }
    return null;
}

pub fn getActiveFile(self: *@This()) ?*EditingText {
    if (self.current_file) |current_file| {
        return self.editing_files.getPtr(current_file);
    }
    return null;
}

pub fn setEditingFile(self: *@This(), file_name: []const u8, text: *Buffer) !void {
    if (!self.editing_files.contains(file_name)) {
        const key = try self.allocator.dupe(u8, file_name);
        errdefer self.allocator.free(key);
        try self.editing_files.putNoClobber(key, .{
            .text = text,
            .cursor = .{
                .buffer = text,
                .x = 0,
                .y = 0,
            },
            .y_scroll = 0,
        });
    }
    errdefer self.deleteEditingFile(file_name);
    const file = self.editing_files.getEntry(file_name).?;
    self.current_file = file.key_ptr.*;
    self.active_cursor = &file.value_ptr.cursor;
    self.active_text = file.value_ptr;
}

pub fn deleteEditingFile(self: *@This(), file_name: []const u8) void {
    if (self.current_file) |current_file| {
        if (std.mem.eql(u8, file_name, current_file)) {
            self.current_file = null;
            self.active_cursor = null;
            self.active_text = null;
        }
    }
    if (self.editing_files.fetchRemove(file_name)) |file| {
        self.allocator.free(file.key);
    }
}

test {
    std.testing.refAllDecls(@This());
}
