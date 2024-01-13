const std = @import("std");
const UnicodeString = @import("UnicodeString.zig");
const models = @import("models.zig");
const Cursor = @import("Cursor.zig");
const Position = @import("Position.zig");

pub const Mode = enum {
    file,
    command,
};

rows: std.ArrayList(UnicodeString),
y_scroll: usize,
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) !*@This() {
    const text = try allocator.create(@This());
    errdefer allocator.destroy(text);
    var rows = std.ArrayList(UnicodeString).init(allocator);
    errdefer rows.deinit();
    errdefer for (rows.items) |row| row.deinit();
    {
        var l = try UnicodeString.init(allocator);
        errdefer l.deinit();
        try rows.append(l);
    }
    text.* = .{
        .rows = rows,
        .y_scroll = 0,
        .allocator = allocator,
    };
    return text;
}

pub fn deinit(self: *const @This()) void {
    for (self.rows.items) |row| row.deinit();
    self.rows.deinit();
    self.allocator.destroy(self);
}

pub fn clone(self: *const @This()) !*@This() {
    var text = try self.allocator.create(@This());
    errdefer self.allocator.destroy(text);
    text.* = self.*;
    text.rows = std.ArrayList(UnicodeString).init(self.allocator);
    errdefer {
        for (text.rows.items) |row| {
            row.deinit();
        }
        text.rows.deinit();
    }
    for (self.rows.items) |row| {
        const cloned = try row.clone();
        errdefer cloned.deinit();
        try text.rows.append(cloned);
    }
    return text;
}

pub fn insertChar(self: *@This(), pos: Position, c: u21) !void {
    try self.rows.items[pos.y].insert(pos.x, c);
}

pub fn deleteChar(self: *@This(), pos: Position) !void {
    var row = &self.rows.items[pos.y];
    if (pos.x >= row.getLen()) {
        try self.joinLine(pos);
        return;
    }
    try row.remove(pos.x);
}

pub fn deleteBackwardChar(self: *@This()) !void {
    try self.moveBackward();
    try self.deleteChar();
}

pub fn joinLine(self: *@This(), pos: Position) !void {
    if (pos.y >= self.rows.items.len - 1) {
        return;
    }
    var row = &self.rows.items[pos.y];
    var next_row = &self.rows.items[pos.y + 1];
    try row.appendSlice(next_row.buffer.items);
    next_row.deinit();
    _ = self.rows.orderedRemove(pos.y + 1);
}

pub fn killLine(self: *@This(), pos: Position) !void {
    var row = &self.rows.items[pos.y];
    if (pos.x >= row.getLen()) {
        try self.deleteChar(pos);
        return;
    }
    for (0..row.getLen() - pos.x) |_| {
        try self.deleteChar(pos);
    }
}

pub fn breakLine(self: *@This(), pos: Position) !void {
    var new_row = try UnicodeString.init(self.allocator);
    errdefer new_row.deinit();
    const row = &self.rows.items[pos.y];
    if (pos.x < row.getLen()) {
        for (0..row.getLen() - pos.x) |_| {
            try new_row.appendSlice(row.buffer.items[row.u8_index.items[pos.x]..row.u8_index.items[pos.x + 1]]);
            try self.deleteChar(pos);
        }
    }
    try self.rows.insert(pos.y + 1, new_row);
}

pub fn clear(self: *@This()) !void {
    std.debug.assert(self.rows.items.len == 1);
    try self.rows.items[0].clear();
}

pub fn openFile(self: *@This(), path: []const u8) !void {
    var f = try std.fs.cwd().openFile(path, .{});
    defer f.close();
    var reader = f.reader();

    var new_rows = std.ArrayList(UnicodeString).init(self.allocator);
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
        var new_row = try UnicodeString.init(self.allocator);
        errdefer new_row.deinit();
        try new_row.appendSlice(buf.items);
        try new_rows.append(new_row);
    }
    var last_row = try UnicodeString.init(self.allocator);
    errdefer last_row.deinit();
    try new_rows.append(last_row);

    for (self.rows.items) |row| row.deinit();
    self.rows.deinit();
    self.rows = new_rows;
}

pub fn saveFile(self: *const @This(), path: []const u8) !void {
    var f = try std.fs.cwd().createFile(path, .{});
    defer f.close();
    for (self.rows.items, 0..) |row, i| {
        if (i > 0)
            _ = try f.write("\n");
        _ = try f.write(row.buffer.items);
    }
}