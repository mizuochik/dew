const std = @import("std");
const Buffer = @import("Buffer.zig");
const Cursor = @import("Cursor.zig");
const Status = @import("Status.zig");

current_file: ?[]const u8 = null,
cursors: std.StringHashMap(std.ArrayList(Cursor)),
scroll_positions: std.StringHashMap(usize),
command_line: *Buffer,
status: Status,

pub fn init(allocator: std.mem.Allocator) !@This() {
    var command_line = try Buffer.init(allocator, .command);
    errdefer command_line.deinit();
    var st = try Status.init(allocator);
    errdefer st.deinit();
    return .{
        .cursors = std.StringHashMap(std.ArrayList(Cursor)).init(allocator),
        .scroll_positions = std.StringHashMap(usize).init(allocator),
        .command_line = command_line,
        .status = st,
    };
}

pub fn deinit(self: *@This()) void {
    self.cursors.deinit();
    self.scroll_positions.deinit();
}

test {
    std.testing.refAllDecls(@This());
}
