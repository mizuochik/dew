const std = @import("std");
const dew = @import("../../dew.zig");

file_buffer_view: *dew.view.BufferView,
command_buffer_view: *dew.view.BufferView,
status_message: *dew.models.StatusMessage,
file_path: ?[]const u8 = null,
model_event_publisher: *const dew.event.Publisher(dew.models.Event),
buffer_selector: *dew.models.BufferSelector,
allocator: std.mem.Allocator,

const EditorController = @This();

pub fn init(allocator: std.mem.Allocator, file_buffer_view: *dew.view.BufferView, command_buffer_view: *dew.view.BufferView, status_message: *dew.models.StatusMessage, buffer_selector: *dew.models.BufferSelector, model_event_publisher: *const dew.event.Publisher(dew.models.Event)) !EditorController {
    return EditorController{
        .allocator = allocator,
        .file_buffer_view = file_buffer_view,
        .command_buffer_view = command_buffer_view,
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
                try cursor.moveBackward();
                try self.buffer_selector.current_buffer.deleteChar(cursor.getPosition());
            }
        },
        .ctrl => |k| switch (k) {
            'Q' => return error.Quit,
            'S' => try self.saveFile(),
            'K' => try self.killLine(),
            'D' => {
                for (self.buffer_selector.current_buffer.cursors.items) |*cursor| {
                    try self.buffer_selector.current_buffer.deleteChar(cursor.getPosition());
                }
            },
            'H' => {
                for (self.buffer_selector.current_buffer.cursors.items) |*cursor| {
                    try cursor.moveBackward();
                    try self.buffer_selector.current_buffer.deleteChar(cursor.getPosition());
                }
            },
            'M' => {
                switch (self.buffer_selector.current_buffer.mode) {
                    .command => {
                        try self.buffer_selector.command_buffer.evaluateCommand();
                    },
                    else => {
                        try self.breakLine();
                    },
                }
            },
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
                self.file_buffer_view.updateLastCursorX();
            },
            'E' => {
                for (self.buffer_selector.current_buffer.cursors.items) |*cursor| {
                    try cursor.moveToEndOfLine();
                }
                self.file_buffer_view.updateLastCursorX();
            },
            'X' => {
                try self.buffer_selector.toggleCommandBuffer();
            },
            'V' => {
                self.file_buffer_view.scrollDown(self.file_buffer_view.height * 15 / 16);
                const pos = self.file_buffer_view.getNormalizedCursor();
                for (self.buffer_selector.current_buffer.cursors.items) |*cursor| {
                    try cursor.setPosition(pos);
                }
            },
            else => {},
        },
        .meta => |k| switch (k) {
            'v' => {
                self.file_buffer_view.scrollUp(self.file_buffer_view.height * 15 / 16);
                const pos = self.file_buffer_view.getNormalizedCursor();
                for (self.buffer_selector.current_buffer.cursors.items) |*cursor| {
                    try cursor.setPosition(pos);
                }
            },
            else => {},
        },
        .plain => |k| {
            for (self.buffer_selector.current_buffer.cursors.items) |*cursor| {
                try self.buffer_selector.current_buffer.insertChar(cursor.getPosition(), k);
                try cursor.moveForward();
            }
        },
        .arrow => |k| try self.moveCursor(k),
    }
}

fn moveCursor(self: *EditorController, k: dew.models.Arrow) !void {
    switch (k) {
        .up => {
            const y = self.file_buffer_view.getCursor().y;
            if (y > 0) {
                const pos = self.file_buffer_view.getBufferPopsition(.{ .x = self.file_buffer_view.last_cursor_x, .y = y - 1 });
                for (self.buffer_selector.current_buffer.cursors.items) |*cursor| {
                    try cursor.setPosition(pos);
                }
            }
        },
        .down => {
            const y = self.file_buffer_view.getCursor().y;
            if (y < self.file_buffer_view.getNumberOfLines() - 1) {
                const pos = self.file_buffer_view.getBufferPopsition(.{ .x = self.file_buffer_view.last_cursor_x, .y = y + 1 });
                for (self.buffer_selector.current_buffer.cursors.items) |*cursor| {
                    try cursor.setPosition(pos);
                }
            }
        },
        .left => {
            for (self.buffer_selector.current_buffer.cursors.items) |*cursor| {
                try cursor.moveBackward();
            }
            self.file_buffer_view.updateLastCursorX();
        },
        .right => {
            for (self.buffer_selector.current_buffer.cursors.items) |*cursor| {
                try cursor.moveForward();
            }
            self.file_buffer_view.updateLastCursorX();
        },
    }
}

fn breakLine(self: *EditorController) !void {
    for (self.buffer_selector.current_buffer.cursors.items) |*cursor| {
        try self.buffer_selector.current_buffer.breakLine(cursor.getPosition());
        try cursor.moveForward();
    }
    self.file_buffer_view.updateLastCursorX();
}

fn killLine(self: *EditorController) !void {
    for (self.buffer_selector.current_buffer.cursors.items) |*cursor| {
        try self.buffer_selector.current_buffer.killLine(cursor.getPosition());
    }
    self.file_buffer_view.updateLastCursorX();
}

fn insertChar(self: *EditorController, char: u21) !void {
    try self.buffer_selector.current_buffer.insertChar(char);
    self.file_buffer_view.updateLastCursorX();
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
