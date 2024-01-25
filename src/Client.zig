const std = @import("std");
const Text = @import("Text.zig");
const Cursor = @import("Cursor.zig");
const Status = @import("Status.zig");

pub const Edit = struct {
    text: *Text,
    cursor: Cursor,
    y_scroll: usize = 0,

    pub fn init(text: *Text) @This() {
        return .{
            .text = text,
            .cursor = .{
                .text = text,
            },
        };
    }
};

current_file: ?[]const u8 = null,
scroll_positions: std.StringHashMap(usize),
method_line: *Text,
method_line_edit: Edit,
status: Status,
file_edits: std.StringHashMap(Edit),
active_edit: ?*Edit = null,
allocator: std.mem.Allocator,
is_method_line_active: bool = false,

pub fn init(allocator: std.mem.Allocator) !@This() {
    var method_line = try Text.init(allocator);
    errdefer method_line.deinit();
    var st = try Status.init(allocator);
    errdefer st.deinit();
    const file_edits = std.StringHashMap(Edit).init(allocator);
    errdefer file_edits.deinit();
    return .{
        .scroll_positions = std.StringHashMap(usize).init(allocator),
        .method_line = method_line,
        .file_edits = file_edits,
        .status = st,
        .allocator = allocator,
        .method_line_edit = Edit.init(method_line),
    };
}

pub fn deinit(self: *@This()) void {
    self.method_line.deinit();
    self.status.deinit();
    self.scroll_positions.deinit();
    var editing_file_keys = self.file_edits.keyIterator();
    while (editing_file_keys.next()) |key| self.allocator.free(key.*);
    self.file_edits.deinit();
}

pub fn toggleMethodLine(self: *@This()) !void {
    if (self.is_method_line_active) {
        try self.method_line.clear();
        self.method_line_edit.cursor.x = 0;
        self.is_method_line_active = false;
        self.active_edit = self.getActiveFile();
    } else {
        self.is_method_line_active = true;
        self.active_edit = &self.method_line_edit;
    }
}

pub fn getActiveFile(self: *@This()) ?*Edit {
    if (self.current_file) |current_file| {
        return self.file_edits.getPtr(current_file);
    }
    return null;
}

pub fn getActiveEdit(self: *@This()) ?*Edit {
    if (self.is_method_line_active) {
        return &self.method_line_edit;
    }
    return self.getActiveFile();
}

pub fn putFileEdit(self: *@This(), file_name: []const u8, text: *Text) !void {
    const result = try self.file_edits.getOrPut(file_name);
    errdefer if (!result.found_existing) {
        _ = self.file_edits.remove(file_name);
    };
    if (!result.found_existing) {
        result.key_ptr.* = try self.allocator.dupe(u8, file_name);
    }
    errdefer if (!result.found_existing) {
        self.allocator.free(result.key_ptr.*);
    };
    result.value_ptr.* = Edit.init(text);
    self.current_file = result.key_ptr.*;
    self.active_edit = result.value_ptr;
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
