const std = @import("std");
const Text = @import("Text.zig");
const Position = @import("Position.zig");
const UnicodeString = @import("UnicodeString.zig");

text: *Text,
x: usize = 0,
y: usize = 0,
last_view_x: usize = 0,

pub fn moveForward(self: *@This()) !void {
    if (self.x < self.getCurrentRow().getLen()) {
        self.x += 1;
    } else if (self.y < self.text.rows.items.len - 1) {
        self.y += 1;
        self.x = 0;
    }
}

pub fn moveBackward(self: *@This()) !void {
    if (self.x > 0) {
        self.x -= 1;
    } else if (self.y > 0) {
        self.y -= 1;
        self.x = self.getCurrentRow().getLen();
    }
}

pub fn moveToBeginningOfLine(self: *@This()) !void {
    self.x = 0;
}

pub fn moveToEndOfLine(self: *@This()) !void {
    self.x = self.getCurrentRow().getLen();
}

pub fn getPosition(self: *const @This()) Position {
    return .{
        .x = self.x,
        .y = self.y,
    };
}

pub fn setPosition(self: *@This(), pos: Position) !void {
    self.x = pos.x;
    self.y = pos.y;
}

fn getCurrentRow(self: *const @This()) UnicodeString {
    return self.text.rows.items[self.y];
}
