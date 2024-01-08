const std = @import("std");
const Buffer = @import("Buffer.zig");
const Cursor = @import("Cursor.zig");
const Status = @import("Status.zig");

current_file: ?[]const u8 = null,
cursors: std.StringHashMap(Cursor),
command_cursor: Cursor,
scroll_positions: std.StringHashMap(usize),
command_line: *Buffer,
status: Status,
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) !@This() {
    var command_line = try Buffer.init(allocator, .command);
    errdefer command_line.deinit();
    try command_line.addCursor();
    const command_cursor = .{
        .buffer = command_line,
        .x = 0,
        .y = 0,
    };
    var st = try Status.init(allocator);
    errdefer st.deinit();
    return .{
        .cursors = std.StringHashMap(Cursor).init(allocator),
        .command_cursor = command_cursor,
        .scroll_positions = std.StringHashMap(usize).init(allocator),
        .command_line = command_line,
        .status = st,
        .allocator = allocator,
    };
}

pub fn deinit(self: *@This()) void {
    var ki = self.cursors.keyIterator();
    while (ki.next()) |key| self.allocator.free(key.*);
    self.cursors.deinit();
    self.command_line.deinit();
    self.status.deinit();
    self.scroll_positions.deinit();
    if (self.current_file) |current_file| {
        self.allocator.free(current_file);
    }
}

pub fn setCurrentFile(self: *@This(), file_name: []const u8) !void {
    if (self.current_file) |current_file| {
        if (std.mem.eql(u8, file_name, current_file)) {
            return;
        }
        const duped = try self.allocator.dupe(u8, file_name);
        errdefer self.allocator.free(duped);
        self.allocator.free(current_file);
        self.current_file = duped;
        return;
    }
    const duped = try self.allocator.dupe(u8, file_name);
    errdefer self.allocator.free(duped);
    self.current_file = duped;
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

pub fn getActiveCursor(self: *const @This()) *Cursor {
    return self.cursors.getPtr(self.current_file.?) orelse unreachable;
}

test {
    std.testing.refAllDecls(@This());
}
