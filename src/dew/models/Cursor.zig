const dew = @import("../../dew.zig");

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

fn getCurrentRow(self: *const Cursor) dew.models.UnicodeString {
    return self.buffer.rows.items[self.y];
}
