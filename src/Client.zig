const std = @import("std");
const Text = @import("Text.zig");
const Cursor = @import("Cursor.zig");
const Status = @import("Status.zig");

pub const Edit = struct {
    text: *Text,
    cursor: Cursor,
    y_scroll: usize,
};

current_file: ?[]const u8 = null,
scroll_positions: std.StringHashMap(usize),
command_line: *Text,
command_line_edit: Edit,
status: Status,
file_edits: std.StringHashMap(Edit),
active_edit: ?*Edit = null,
allocator: std.mem.Allocator,
is_command_line_active: bool = false,

pub fn init(allocator: std.mem.Allocator) !@This() {
    var command_line = try Text.init(allocator);
    errdefer command_line.deinit();
    var st = try Status.init(allocator);
    errdefer st.deinit();
    const file_edits = std.StringHashMap(Edit).init(allocator);
    errdefer file_edits.deinit();
    return .{
        .scroll_positions = std.StringHashMap(usize).init(allocator),
        .command_line = command_line,
        .file_edits = file_edits,
        .status = st,
        .allocator = allocator,
        .command_line_edit = .{
            .text = command_line,
            .cursor = .{
                .text = command_line,
                .x = 0,
                .y = 0,
            },
            .y_scroll = 0,
        },
    };
}

pub fn deinit(self: *@This()) void {
    self.command_line.deinit();
    self.status.deinit();
    self.scroll_positions.deinit();
    var editing_file_keys = self.file_edits.keyIterator();
    while (editing_file_keys.next()) |key| self.allocator.free(key.*);
    self.file_edits.deinit();
}

pub fn toggleCommandLine(self: *@This()) !void {
    if (self.is_command_line_active) {
        try self.command_line.clear();
        self.command_line_edit.cursor.x = 0;
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

pub fn getActiveEdit(self: *@This()) ?*Edit {
    if (self.is_command_line_active) {
        return &self.command_line_edit;
    }
    return self.getActiveFile();
}

pub fn putFileEdit(self: *@This(), file_name: []const u8, text: *Text) !void {
    if (!self.file_edits.contains(file_name)) {
        const key = try self.allocator.dupe(u8, file_name);
        errdefer self.allocator.free(key);
        try self.file_edits.putNoClobber(key, .{
            .text = text,
            .cursor = .{
                .text = text,
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
