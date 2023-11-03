const dew = @import("../../dew.zig");
const std = @import("std");

buffer: *dew.models.Buffer,
x: usize = 0,
y: usize = 0,
event_publisher: *const dew.event.Publisher(dew.models.Event),

const Cursor = @This();

pub fn moveForward(self: *Cursor) !void {
    if (self.x < self.getCurrentRow().getLen()) {
        self.x += 1;
        try self.event_publisher.publish(.cursor_moved);
    } else if (self.y < self.buffer.rows.items.len - 1) {
        self.y += 1;
        self.x = 0;
        try self.event_publisher.publish(.cursor_moved);
    }
}

pub fn moveBackward(self: *Cursor) !void {
    if (self.x > 0) {
        self.x -= 1;
    } else if (self.y > 0) {
        self.y -= 1;
        self.x = self.getCurrentRow().getLen();
    }
    try self.event_publisher.publish(.cursor_moved);
}

pub fn moveToBeginningOfLine(self: *Cursor) !void {
    self.x = 0;
    try self.event_publisher.publish(.cursor_moved);
}

pub fn moveToEndOfLine(self: *Cursor) !void {
    self.x = self.getCurrentRow().getLen();
    try self.event_publisher.publish(.cursor_moved);
}

pub fn insertChar(self: *Cursor, c: u21) !void {
    try self.buffer._insertChar(self.getPosition(), c);
    try self.moveForward();
}

pub fn deleteChar(self: *Cursor) !void {
    try self.buffer._deleteChar(self.getPosition());
    try self.event_publisher.publish(.cursor_moved);
}

pub fn deleteBackwardChar(self: *Cursor) !void {
    try self.moveBackward();
    try self.deleteChar();
}

pub fn getPosition(self: *const Cursor) dew.models.Position {
    return .{
        .x = self.x,
        .y = self.y,
    };
}

pub fn setPosition(self: *Cursor, pos: dew.models.Position) !void {
    self.x = pos.x;
    self.y = pos.y;
    try self.event_publisher.publish(.cursor_moved);
}

fn getCurrentRow(self: *const Cursor) dew.models.UnicodeString {
    return self.buffer.rows.items[self.y];
}
