const std = @import("std");
const Buffer = @import("Buffer.zig");
const Cursor = @import("Cursor.zig");
const Status = @import("Status.zig");

pub const Edit = struct {
    text: *Buffer,
    cursor: Cursor,
    y_scroll: usize,
};

current_file: ?[]const u8 = null,
cursors: std.StringHashMap(Cursor),
command_cursor: Cursor,
scroll_positions: std.StringHashMap(usize),
command_line: *Buffer,
command_line_edit: Edit,
status: Status,
file_edits: std.StringHashMap(Edit),
active_edit: ?*Edit = null,
allocator: std.mem.Allocator,
is_command_line_active: bool = false,

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
    const file_edits = std.StringHashMap(Edit).init(allocator);
    errdefer file_edits.deinit();
    return .{
        .cursors = std.StringHashMap(Cursor).init(allocator),
        .command_cursor = command_cursor,
        .scroll_positions = std.StringHashMap(usize).init(allocator),
        .command_line = command_line,
        .file_edits = file_edits,
        .status = st,
        .allocator = allocator,
        .command_line_edit = .{
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
    var editing_file_keys = self.file_edits.keyIterator();
    while (editing_file_keys.next()) |key| self.allocator.free(key.*);
    self.file_edits.deinit();
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
        self.active_edit = self.getActiveFile();
    } else {
        self.is_command_line_active = true;
        self.active_edit = &self.command_line_edit;
    }
}

pub fn getActiveFile(self: *@This()) ?*Edit {
    if (self.current_file) |current_file| {
        return self.file_edits.getPtr(current_file);
    }
    return null;
}

pub fn putFileEdit(self: *@This(), file_name: []const u8, text: *Buffer) !void {
    if (!self.file_edits.contains(file_name)) {
        const key = try self.allocator.dupe(u8, file_name);
        errdefer self.allocator.free(key);
        try self.file_edits.putNoClobber(key, .{
            .text = text,
            .cursor = .{
                .buffer = text,
                .x = 0,
                .y = 0,
            },
            .y_scroll = 0,
        });
    }
    errdefer self.removeFileEdit(file_name);
    const file = self.file_edits.getEntry(file_name).?;
    self.current_file = file.key_ptr.*;
    self.active_edit = file.value_ptr;
}

pub fn removeFileEdit(self: *@This(), file_name: []const u8) void {
    if (self.current_file) |current_file| {
        if (std.mem.eql(u8, file_name, current_file)) {
            self.current_file = null;
            self.active_edit = null;
        }
    }
    if (self.file_edits.fetchRemove(file_name)) |file| {
        self.allocator.free(file.key);
    }
}

test {
    std.testing.refAllDecls(@This());
}
