const std = @import("std");
const Text = @import("Text.zig");
const Selection = @import("Selection.zig");
const Status = @import("Status.zig");
const TextRef = @import("TextRef.zig");

current_file: ?[]const u8 = null,
command_line: *Text,
command_line_ref: TextRef,
status: Status,
file_refs: std.StringHashMap(TextRef),
active_ref: ?*TextRef = null,
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) !@This() {
    var command_line = try Text.init(allocator);
    errdefer command_line.deinit();
    var st = try Status.init(allocator);
    errdefer st.deinit();
    const file_refs = std.StringHashMap(TextRef).init(allocator);
    errdefer file_refs.deinit();
    return .{
        .command_line = command_line,
        .file_refs = file_refs,
        .status = st,
        .allocator = allocator,
        .command_line_ref = TextRef.init(command_line),
    };
}

pub fn deinit(self: *@This()) void {
    self.command_line.deinit();
    self.status.deinit();
    var editing_file_keys = self.file_refs.keyIterator();
    while (editing_file_keys.next()) |key| self.allocator.free(key.*);
    self.file_refs.deinit();
}

pub fn toggleCommandLine(self: *@This()) !void {
    if (self.isCommandLineActive()) {
        try self.command_line.clear();
        self.command_line_ref.selection.x = 0;
        self.active_ref = self.getActiveFile();
    } else {
        self.active_ref = &self.command_line_ref;
    }
}

pub fn getActiveFile(self: *@This()) ?*TextRef {
    if (self.current_file) |current_file| {
        return self.file_refs.getPtr(current_file);
    }
    return null;
}

pub fn getActiveEdit(self: *@This()) ?*TextRef {
    if (self.isCommandLineActive()) {
        return &self.command_line_ref;
    }
    return self.getActiveFile();
}

pub fn putFileRef(self: *@This(), file_name: []const u8, text: *Text) !void {
    const result = try self.file_refs.getOrPut(file_name);
    errdefer if (!result.found_existing) {
        _ = self.file_refs.remove(file_name);
    };
    if (!result.found_existing) {
        result.key_ptr.* = try self.allocator.dupe(u8, file_name);
    }
    errdefer if (!result.found_existing) {
        self.allocator.free(result.key_ptr.*);
    };
    result.value_ptr.* = TextRef.init(text);
    self.current_file = result.key_ptr.*;
    if (!self.isCommandLineActive())
        self.active_ref = result.value_ptr;
}

pub fn removeFileRef(self: *@This(), file_name: []const u8) void {
    if (self.current_file) |current_file| {
        if (std.mem.eql(u8, file_name, current_file)) {
            self.current_file = null;
            if (!self.isCommandLineActive())
                self.active_ref = null;
        }
    }
    if (self.file_refs.fetchRemove(file_name)) |file| {
        self.allocator.free(file.key);
    }
}

pub fn isCommandLineActive(self: *const @This()) bool {
    return self.active_ref == &self.command_line_ref;
}

test {
    std.testing.refAllDecls(@This());
}
