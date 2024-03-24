const Selection = @This();
const std = @import("std");
const Text = @import("Text.zig");
const Position = @import("Position.zig");
const UnicodeString = @import("UnicodeString.zig");

text: *Text,
cursor: Position = .{ .line = 0, .character = 0 },
last_view_x: usize = 0,

pub fn moveForward(self: *Selection) !void {
    if (self.cursor.character < self.getCurrentRow().getLen()) {
        self.cursor.character += 1;
    } else if (self.cursor.line < self.text.rows.items.len - 1) {
        self.cursor.line += 1;
        self.cursor.character = 0;
    }
}

pub fn moveBackward(self: *Selection) !void {
    if (self.cursor.character > 0) {
        self.cursor.character -= 1;
    } else if (self.cursor.line > 0) {
        self.cursor.line -= 1;
        self.cursor.character = self.getCurrentRow().getLen();
    }
}

pub fn moveToBeginningOfLine(self: *Selection) !void {
    self.cursor.character = 0;
}

pub fn moveToEndOfLine(self: *Selection) !void {
    self.cursor.character = self.getCurrentRow().getLen();
}

pub fn getPosition(self: *const Selection) Position {
    return self.cursor;
}

pub fn setPosition(self: *Selection, pos: Position) !void {
    const line = @min(self.text.rows.items.len, pos.line);
    const character = @min(self.text.rows.items[line].getLen(), pos.character);
    self.cursor = .{
        .line = line,
        .character = character,
    };
}

fn getCurrentRow(self: *const Selection) UnicodeString {
    return self.text.rows.items[self.cursor.line];
}
