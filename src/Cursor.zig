const std = @import("std");
const models = @import("models.zig");
const Buffer = @import("Buffer.zig");
const Position = @import("Position.zig");
const UnicodeString = @import("UnicodeString.zig");

buffer: *Buffer,
x: usize = 0,
y: usize = 0,

const Cursor = @This();

pub fn moveForward(self: *Cursor) !void {
    if (self.x < self.getCurrentRow().getLen()) {
        self.x += 1;
    } else if (self.y < self.buffer.rows.items.len - 1) {
        self.y += 1;
        self.x = 0;
    }
}

pub fn moveBackward(self: *Cursor) !void {
    if (self.x > 0) {
        self.x -= 1;
    } else if (self.y > 0) {
        self.y -= 1;
        self.x = self.getCurrentRow().getLen();
    }
}

pub fn moveToBeginningOfLine(self: *Cursor) !void {
    self.x = 0;
}

pub fn moveToEndOfLine(self: *Cursor) !void {
    self.x = self.getCurrentRow().getLen();
}

pub fn getPosition(self: *const Cursor) Position {
    return .{
        .x = self.x,
        .y = self.y,
    };
}

pub fn setPosition(self: *Cursor, pos: Position) !void {
    self.x = pos.x;
    self.y = pos.y;
}

fn getCurrentRow(self: *const Cursor) UnicodeString {
    return self.buffer.rows.items[self.y];
}
