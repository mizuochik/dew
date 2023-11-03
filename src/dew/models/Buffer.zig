const std = @import("std");
const dew = @import("../../dew.zig");

const Buffer = @This();

const Mode = enum {
    file,
    command,
};

rows: std.ArrayList(dew.models.UnicodeString),
c_x: usize = 0,
c_y: usize = 0,
event_publisher: *dew.event.Publisher(dew.models.Event),
mode: Mode,
cursors: std.ArrayList(dew.models.Cursor),
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator, event_publisher: *dew.event.Publisher(dew.models.Event), mode: Mode) !Buffer {
    var buf = .{
        .rows = std.ArrayList(dew.models.UnicodeString).init(allocator),
        .event_publisher = event_publisher,
        .mode = mode,
        .cursors = std.ArrayList(dew.models.Cursor).init(allocator),
        .allocator = allocator,
    };
    if (mode == Mode.command) {
        var l = try dew.models.UnicodeString.init(allocator);
        errdefer l.deinit();
        try buf.rows.append(l);
    }
    return buf;
}

pub fn deinit(self: *const Buffer) void {
    for (self.rows.items) |row| row.deinit();
    self.rows.deinit();
    self.cursors.deinit();
}

pub fn addCursor(self: *Buffer) !void {
    try self.cursors.append(dew.models.Cursor{
        .buffer = self,
        .event_publisher = self.event_publisher,
    });
}

pub fn insertChar(self: *Buffer, pos: dew.models.Position, c: u21) !void {
    try self.rows.items[pos.y].insert(pos.x, c);
    try self.notifyUpdate();
}

pub fn deleteChar(self: *Buffer, pos: dew.models.Position) !void {
    var row = &self.rows.items[pos.y];
    if (pos.x >= row.getLen()) {
        try self.joinLine(pos);
        return;
    }
    try row.remove(pos.x);
    try self.notifyUpdate();
}

pub fn deleteBackwardChar(self: *Buffer) !void {
    try self.moveBackward();
    try self.deleteChar();
    try self.notifyUpdate();
}

pub fn joinLine(self: *Buffer, pos: dew.models.Position) !void {
    if (pos.y >= self.rows.items.len - 1) {
        return;
    }
    var row = &self.rows.items[pos.y];
    var next_row = &self.rows.items[pos.y + 1];
    try row.appendSlice(next_row.buffer.items);
    next_row.deinit();
    _ = self.rows.orderedRemove(pos.y + 1);
    try self.notifyUpdate();
}

pub fn killLine(self: *Buffer, pos: dew.models.Position) !void {
    var row = &self.rows.items[pos.y];
    if (pos.x >= row.getLen()) {
        try self.deleteChar(pos);
        return;
    }
    for (0..row.getLen() - pos.x) |_| {
        try self.deleteChar(pos);
    }
    try self.notifyUpdate();
}

pub fn breakLine(self: *Buffer, pos: dew.models.Position) !void {
    if (self.mode == Mode.command) {
        const command_line = try self.rows.items[0].clone();
        errdefer command_line.deinit();
        try self.clear();
        try self.event_publisher.publish(.{ .command_executed = command_line });
        return;
    }
    var new_row = try dew.models.UnicodeString.init(self.allocator);
    errdefer new_row.deinit();
    const row = &self.rows.items[pos.y];
    if (pos.x < row.getLen()) {
        for (0..row.getLen() - pos.x) |_| {
            try new_row.appendSlice(row.buffer.items[row.u8_index.items[pos.x]..row.u8_index.items[pos.x + 1]]);
            try self.deleteChar(pos);
        }
    }
    try self.rows.insert(pos.y + 1, new_row);
    try self.notifyUpdate();
}

pub fn clear(self: *Buffer) !void {
    std.debug.assert(self.rows.items.len == 1);
    try self.rows.items[0].clear();
    try self.event_publisher.publish(dew.models.Event{ .buffer_updated = .{ .from = .{ .x = 0, .y = 0 }, .to = .{ .x = 0, .y = 0 } } });
}

pub fn notifyUpdate(self: *Buffer) !void {
    try self.event_publisher.publish(.{ .buffer_updated = .{ .from = .{ .x = 0, .y = 0 }, .to = .{ .x = 0, .y = 0 } } });
}

pub fn openFile(self: *Buffer, path: []const u8) !void {
    var f = try std.fs.cwd().openFile(path, .{});
    defer f.close();
    var reader = f.reader();

    var new_rows = std.ArrayList(dew.models.UnicodeString).init(self.allocator);
    errdefer {
        for (new_rows.items) |row| row.deinit();
        new_rows.deinit();
    }

    while (true) {
        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();
        reader.streamUntilDelimiter(buf.writer(), '\n', null) catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };
        var new_row = try dew.models.UnicodeString.init(self.allocator);
        errdefer new_row.deinit();
        try new_row.appendSlice(buf.items);
        try new_rows.append(new_row);
    }

    var last_row = try dew.models.UnicodeString.init(self.allocator);
    errdefer last_row.deinit();
    try new_rows.append(last_row);

    for (self.rows.items) |row| row.deinit();
    self.rows.deinit();
    self.rows = new_rows;
    try self.notifyUpdate();
}

test "Buffer: moveForward" {
    var event_publisher = dew.event.Publisher.init(std.testing.allocator);
    defer event_publisher.deinit();
    var buf = try Buffer.init(std.testing.allocator, &event_publisher, .file);
    defer buf.deinit();
    const lines = [_][]const u8{
        "ab",
        "cd",
        "",
    };
    for (lines) |line| {
        var l = try dew.models.UnicodeString.init(std.testing.allocator);
        errdefer l.deinit();
        try l.appendSlice(line);
        try buf.rows.append(l);
    }

    try std.testing.expectFmt("0 0", "{} {}", .{ buf.c_x, buf.c_y });

    try buf.moveForward();
    try std.testing.expectFmt("1 0", "{} {}", .{ buf.c_x, buf.c_y });

    try buf.moveForward();
    try std.testing.expectFmt("2 0", "{} {}", .{ buf.c_x, buf.c_y });

    try buf.moveForward();
    try std.testing.expectFmt("0 1", "{} {}", .{ buf.c_x, buf.c_y });

    try buf.moveForward();
    try std.testing.expectFmt("1 1", "{} {}", .{ buf.c_x, buf.c_y });

    try buf.moveForward();
    try std.testing.expectFmt("2 1", "{} {}", .{ buf.c_x, buf.c_y });

    try buf.moveForward();
    try std.testing.expectFmt("0 2", "{} {}", .{ buf.c_x, buf.c_y });

    try buf.moveForward();
    try std.testing.expectFmt("0 2", "{} {}", .{ buf.c_x, buf.c_y });
}
