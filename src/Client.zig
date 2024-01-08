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
    self.cursors.deinit();
    self.scroll_positions.deinit();
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

test {
    std.testing.refAllDecls(@This());
}
