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

pub fn setCursor(self: *Buffer, x: usize, y: usize) !void {
    self.c_x = x;
    self.c_y = switch (self.mode) {
        .command => 0,
        else => y,
    };
    try self.notifyUpdate();
}

pub fn moveForward(self: *Buffer) !void {
    const row = self.getCurrentRow();
    if (self.c_x < row.getLen()) {
        self.c_x += 1;
    } else if (self.c_y < self.rows.items.len - 1) {
        self.c_y += 1;
        self.c_x = 0;
    }
    try self.notifyUpdate();
}

pub fn moveBackward(self: *Buffer) !void {
    if (self.c_x > 0) {
        self.c_x -= 1;
    } else if (self.c_y > 0) {
        self.c_y -= 1;
        self.c_x = self.getCurrentRow().getLen();
    }
    try self.notifyUpdate();
}

pub fn moveToBeginningOfLine(self: *Buffer) !void {
    self.c_x = 0;
    try self.notifyUpdate();
}

pub fn moveToEndOfLine(self: *Buffer) !void {
    self.c_x = self.getCurrentRow().getLen();
    try self.notifyUpdate();
}

pub fn getCurrentRow(self: *const Buffer) *dew.models.UnicodeString {
    return &self.rows.items[self.c_y];
}

pub fn insertChar(self: *Buffer, c: u21) !void {
    try self.getCurrentRow().insert(self.c_x, c);
    try self.moveForward();
    try self.notifyUpdate();
}

pub fn deleteChar(self: *Buffer) !void {
    if (self.c_x >= self.getCurrentRow().getLen()) {
        try self.joinLine();
        return;
    }
    try self.getCurrentRow().remove(self.c_x);
    try self.notifyUpdate();
}

pub fn deleteBackwardChar(self: *Buffer) !void {
    try self.moveBackward();
    try self.deleteChar();
    try self.notifyUpdate();
}

pub fn joinLine(self: *Buffer) !void {
    if (self.c_y >= self.rows.items.len - 1) {
        return;
    }
    var next_row = self.rows.items[self.c_y + 1];
    try self.getCurrentRow().appendSlice(next_row.buffer.items);
    next_row.deinit();
    _ = self.rows.orderedRemove(self.c_y + 1);
    try self.notifyUpdate();
}

pub fn killLine(self: *Buffer) !void {
    const row = self.getCurrentRow();
    if (self.c_x >= row.getLen()) {
        try self.deleteChar();
        return;
    }
    for (0..row.getLen() - self.c_x) |_| {
        try self.deleteChar();
    }
    try self.notifyUpdate();
}

pub fn breakLine(self: *Buffer) !void {
    if (self.mode == Mode.command) {
        const command_line = try self.rows.items[0].clone();
        errdefer command_line.deinit();
        try self.clear();
        try self.event_publisher.publish(.{ .command_executed = command_line });
        return;
    }
    var new_row = try dew.models.UnicodeString.init(self.allocator);
    errdefer new_row.deinit();
    if (self.c_x < self.getCurrentRow().getLen()) {
        for (0..self.getCurrentRow().getLen() - self.c_x) |_| {
            const r = self.getCurrentRow();
            try new_row.appendSlice(r.buffer.items[r.u8_index.items[self.c_x]..r.u8_index.items[self.c_x + 1]]);
            try self.deleteChar();
        }
    }
    try self.rows.insert(self.c_y + 1, new_row);
    try self.moveForward();
    try self.notifyUpdate();
}

pub fn clear(self: *Buffer) !void {
    std.debug.assert(self.rows.items.len == 1);
    try self.rows.items[0].clear();
    try self.setCursor(0, 0);
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
