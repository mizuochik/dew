const std = @import("std");
const dew = @import("../../dew.zig");

buffer_view: *dew.view.BufferView,
status_message: *dew.models.StatusMessage,
file_path: ?[]const u8 = null,
model_event_publisher: *const dew.event.Publisher(dew.models.Event),
buffer_selector: *dew.models.BufferSelector,
allocator: std.mem.Allocator,

const EditorController = @This();

pub fn init(allocator: std.mem.Allocator, buffer_view: *dew.view.BufferView, status_message: *dew.models.StatusMessage, buffer_selector: *dew.models.BufferSelector, model_event_publisher: *const dew.event.Publisher(dew.models.Event)) !EditorController {
    return EditorController{
        .allocator = allocator,
        .buffer_view = buffer_view,
        .status_message = status_message,
        .buffer_selector = buffer_selector,
        .model_event_publisher = model_event_publisher,
    };
}

pub fn deinit(_: *const EditorController) void {}

pub fn processKeypress(self: *EditorController, key: dew.models.Key) !void {
    switch (key) {
        .del => {
            for (self.buffer_selector.current_buffer.cursors.items) |*cursor| {
                try cursor.deleteBackwardChar();
            }
        },
        .ctrl => |k| switch (k) {
            'Q' => return error.Quit,
            'S' => try self.saveFile(),
            'K' => try self.killLine(),
            'D' => {
                for (self.buffer_selector.current_buffer.cursors.items) |*cursor| {
                    try cursor.deleteChar();
                }
            },
            'H' => {
                for (self.buffer_selector.current_buffer.cursors.items) |*cursor| {
                    try cursor.deleteBackwardChar();
                }
            },
            'M' => try self.breakLine(),
            'P' => try self.moveCursor(.up),
            'N' => try self.moveCursor(.down),
            'F' => try self.moveCursor(.right),
            'B' => try self.moveCursor(.left),
            'J' => {
                for (self.buffer_selector.current_buffer.cursors.items) |*cursor| {
                    try self.buffer_selector.current_buffer.joinLine(cursor.getPosition());
                }
            },
            'A' => {
                for (self.buffer_selector.current_buffer.cursors.items) |*cursor| {
                    try cursor.moveToBeginningOfLine();
                }
                self.buffer_view.updateLastCursorX();
            },
            'E' => {
                for (self.buffer_selector.current_buffer.cursors.items) |*cursor| {
                    try cursor.moveToEndOfLine();
                }
                self.buffer_view.updateLastCursorX();
            },
            'X' => {
                try self.buffer_selector.toggleCommandBuffer();
            },
            'V' => {
                self.buffer_view.scrollDown(self.buffer_view.height * 15 / 16);
                const cur = self.buffer_view.getNormalizedCursor();
                try self.buffer_selector.current_buffer.setCursor(cur.x, cur.y);
            },
            else => {},
        },
        .meta => |k| switch (k) {
            'v' => {
                self.buffer_view.scrollUp(self.buffer_view.height * 15 / 16);
                const cur = self.buffer_view.getNormalizedCursor();
                try self.buffer_selector.current_buffer.setCursor(cur.x, cur.y);
            },
            else => {},
        },
        .plain => |k| {
            for (self.buffer_selector.current_buffer.cursors.items) |*cursor| {
                try cursor.insertChar(k);
            }
        },
        .arrow => |k| try self.moveCursor(k),
    }
}

fn moveCursor(self: *EditorController, k: dew.models.Arrow) !void {
    switch (k) {
        .up => {
            const y = self.buffer_view.getCursor().y;
            if (y > 0) {
                const pos = self.buffer_view.getBufferPopsition(.{ .x = self.buffer_view.last_cursor_x, .y = y - 1 });
                for (self.buffer_selector.current_buffer.cursors.items) |*cursor| {
                    try cursor.setPosition(pos);
                }
            }
        },
        .down => {
            const y = self.buffer_view.getCursor().y;
            if (y < self.buffer_view.getNumberOfLines() - 1) {
                const pos = self.buffer_view.getBufferPopsition(.{ .x = self.buffer_view.last_cursor_x, .y = y + 1 });
                for (self.buffer_selector.current_buffer.cursors.items) |*cursor| {
                    try cursor.setPosition(pos);
                }
            }
        },
        .left => {
            for (self.buffer_selector.current_buffer.cursors.items) |*cursor| {
                try cursor.moveBackward();
            }
            self.buffer_view.updateLastCursorX();
        },
        .right => {
            for (self.buffer_selector.current_buffer.cursors.items) |*cursor| {
                try cursor.moveForward();
            }
            self.buffer_view.updateLastCursorX();
        },
    }
    self.buffer_view.normalizeScroll();
}

fn deleteChar(self: *EditorController) !void {
    for (self.buffer_selector.current_buffer.cursors.items) |*cursor| {
        try cursor.deleteChar();
    }
    self.buffer_view.updateLastCursorX();
}

fn deleteBackwardChar(self: *EditorController) !void {
    try self.buffer_selector.current_buffer.deleteBackwardChar();
    self.buffer_view.updateLastCursorX();
}

fn breakLine(self: *EditorController) !void {
    for (self.buffer_selector.current_buffer.cursors.items) |*cursor| {
        try self.buffer_selector.current_buffer.breakLine(cursor.getPosition());
        try cursor.moveForward();
    }
    self.buffer_view.updateLastCursorX();
}

fn killLine(self: *EditorController) !void {
    for (self.buffer_selector.current_buffer.cursors.items) |*cursor| {
        try self.buffer_selector.current_buffer.killLine(cursor.getPosition());
    }
    self.buffer_view.updateLastCursorX();
}

fn insertChar(self: *EditorController, char: u21) !void {
    try self.buffer_selector.current_buffer.insertChar(char);
    self.buffer_view.updateLastCursorX();
}

pub fn openFile(self: *EditorController, path: []const u8) !void {
    try self.buffer_selector.current_buffer.openFile(path);
    const new_message = try std.fmt.allocPrint(self.allocator, "{s}", .{path});
    errdefer self.allocator.free(new_message);
    try self.status_message.setMessage(new_message);
}

fn saveFile(self: *EditorController) !void {
    var f = try std.fs.cwd().createFile(self.file_path.?, .{});
    defer f.close();
    for (self.buffer_selector.current_buffer.rows.items, 0..) |row, i| {
        if (i > 0)
            _ = try f.write("\n");
        _ = try f.write(row.buffer.items);
    }
    const new_status = try std.fmt.allocPrint(self.allocator, "Saved: {s}", .{self.file_path.?});
    errdefer self.allocator.free(new_status);
    try self.status_message.setMessage(new_status);
}
