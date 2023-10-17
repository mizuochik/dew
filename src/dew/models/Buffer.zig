const std = @import("std");
const mem = std.mem;
const testing = std.testing;
const dew = @import("../../dew.zig");
const observer = dew.observer;
const Editor = dew.Editor;
const Arrow = Editor.Arrow;
const View = dew.view.View;
const models = dew.models;
const Publisher = dew.event.Publisher(models.Event);
const UnicodeString = dew.models.UnicodeString;
const Position = dew.models.Position;

const Buffer = @This();

pub const Event = union(enum) {
    updated,
    activated,
    deactivated,
};

const Mode = enum {
    file,
    command,
};

rows: std.ArrayList(UnicodeString),
c_x: usize = 0,
c_y: usize = 0,
mode: Mode,
observer_list: observer.ObserverList(Event),
is_active: bool,
allocator: mem.Allocator,

pub fn init(allocator: mem.Allocator, mode: Mode) !Buffer {
    var buf = .{
        .rows = std.ArrayList(UnicodeString).init(allocator),
        .mode = mode,
        .observer_list = observer.ObserverList(Event).init(allocator),
        .is_active = mode == Mode.file,
        .allocator = allocator,
    };
    errdefer buf.observer_list.deinit();
    if (mode == Mode.command) {
        var l = try UnicodeString.init(allocator);
        errdefer l.deinit();
        try buf.rows.append(l);
    }
    return buf;
}

pub fn deinit(self: *const Buffer) void {
    for (self.rows.items) |row| row.deinit();
    self.rows.deinit();
    self.observer_list.deinit();
}

pub fn addObserver(self: *Buffer, obs: observer.Observer(Event)) !void {
    try self.observer_list.add(obs);
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

pub fn getCurrentRow(self: *const Buffer) *UnicodeString {
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
        return;
    }
    var new_row = try UnicodeString.init(self.allocator);
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

pub fn notifyUpdate(self: *Buffer) !void {
    try self.observer_list.notifyEvent(Event.updated);
}

pub fn activate(self: *Buffer) !void {
    self.is_active = true;
    try self.observer_list.notifyEvent(.activated);
}

pub fn deactivate(self: *Buffer) !void {
    self.is_active = false;
    try self.observer_list.notifyEvent(.deactivated);
}

test "Buffer: moveForward" {
    var event_publisher = Publisher.init(testing.allocator);
    defer event_publisher.deinit();
    var buf = Buffer.init(testing.allocator, &event_publisher, .file);
    defer buf.deinit();
    const lines = [_][]const u8{
        "ab",
        "cd",
        "",
    };
    for (lines) |line| {
        var l = try UnicodeString.init(testing.allocator);
        errdefer l.deinit();
        try l.appendSlice(line);
        try buf.rows.append(l);
    }

    try testing.expectFmt("0 0", "{} {}", .{ buf.c_x, buf.c_y });

    try buf.moveForward();
    try testing.expectFmt("1 0", "{} {}", .{ buf.c_x, buf.c_y });

    try buf.moveForward();
    try testing.expectFmt("2 0", "{} {}", .{ buf.c_x, buf.c_y });

    try buf.moveForward();
    try testing.expectFmt("0 1", "{} {}", .{ buf.c_x, buf.c_y });

    try buf.moveForward();
    try testing.expectFmt("1 1", "{} {}", .{ buf.c_x, buf.c_y });

    try buf.moveForward();
    try testing.expectFmt("2 1", "{} {}", .{ buf.c_x, buf.c_y });

    try buf.moveForward();
    try testing.expectFmt("0 2", "{} {}", .{ buf.c_x, buf.c_y });

    try buf.moveForward();
    try testing.expectFmt("0 2", "{} {}", .{ buf.c_x, buf.c_y });
}
