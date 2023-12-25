const std = @import("std");
const view = @import("../view.zig");
const models = @import("../models.zig");

file_buffer_view: *view.BufferView,
command_buffer_view: *view.BufferView,
status_message: *models.StatusMessage,
file_path: ?[]const u8 = null,
buffer_selector: *models.BufferSelector,
display_size: *view.DisplaySize,
allocator: std.mem.Allocator,

const EditorController = @This();

pub fn init(allocator: std.mem.Allocator, file_buffer_view: *view.BufferView, command_buffer_view: *view.BufferView, status_message: *models.StatusMessage, buffer_selector: *models.BufferSelector, display_size: *view.DisplaySize) !EditorController {
    return EditorController{
        .allocator = allocator,
        .file_buffer_view = file_buffer_view,
        .command_buffer_view = command_buffer_view,
        .status_message = status_message,
        .buffer_selector = buffer_selector,
        .display_size = display_size,
    };
}

pub fn deinit(_: *const EditorController) void {}

pub fn processKeypress(self: *EditorController, key: models.Key) !void {
    switch (key) {
        .del => {
            for (self.buffer_selector.getCurrentBuffer().cursors.items) |*cursor| {
                try cursor.moveBackward();
                try self.buffer_selector.getCurrentBuffer().deleteChar(cursor.getPosition());
            }
        },
        .ctrl => |k| switch (k) {
            'Q' => return error.Quit,
            'S' => try self.buffer_selector.saveFileBuffer(self.buffer_selector.current_file_buffer),
            'K' => try self.killLine(),
            'D' => {
                for (self.buffer_selector.getCurrentBuffer().cursors.items) |*cursor| {
                    try self.buffer_selector.getCurrentBuffer().deleteChar(cursor.getPosition());
                }
            },
            'H' => {
                for (self.buffer_selector.getCurrentBuffer().cursors.items) |*cursor| {
                    try cursor.moveBackward();
                    try self.buffer_selector.getCurrentBuffer().deleteChar(cursor.getPosition());
                }
            },
            'M' => {
                switch (self.buffer_selector.getCurrentBuffer().mode) {
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
                for (self.buffer_selector.getCurrentBuffer().cursors.items) |*cursor| {
                    try self.buffer_selector.getCurrentBuffer().joinLine(cursor.getPosition());
                }
            },
            'A' => {
                for (self.buffer_selector.getCurrentBuffer().cursors.items) |*cursor| {
                    try cursor.moveToBeginningOfLine();
                }
                self.getCurrentView().updateLastCursorX();
            },
            'E' => {
                for (self.buffer_selector.getCurrentBuffer().cursors.items) |*cursor| {
                    try cursor.moveToEndOfLine();
                }
                self.getCurrentView().updateLastCursorX();
            },
            'X' => {
                try self.buffer_selector.toggleCommandBuffer();
            },
            'V' => {
                self.getCurrentView().scrollDown(self.getCurrentView().height);
                const buf_pos = self.getCurrentView().getBufferPopsition(self.getCurrentView().getNormalizedCursor());
                for (self.buffer_selector.getCurrentBuffer().cursors.items) |*cursor| {
                    try cursor.setPosition(buf_pos);
                }
            },
            else => {},
        },
        .meta => |k| switch (k) {
            'v' => {
                self.getCurrentView().scrollUp(self.getCurrentView().height);
                const buf_pos = self.getCurrentView().getBufferPopsition(self.getCurrentView().getNormalizedCursor());
                for (self.buffer_selector.getCurrentBuffer().cursors.items) |*cursor| {
                    try cursor.setPosition(buf_pos);
                }
            },
            else => {},
        },
        .plain => |k| {
            for (self.buffer_selector.getCurrentBuffer().cursors.items) |*cursor| {
                try self.buffer_selector.getCurrentBuffer().insertChar(cursor.getPosition(), k);
                try cursor.moveForward();
            }
        },
        .arrow => |k| try self.moveCursor(k),
    }
}

pub fn changeDisplaySize(self: *const EditorController, cols: usize, rows: usize) !void {
    try self.display_size.set(cols, rows);
}

fn moveCursor(self: *EditorController, k: models.Arrow) !void {
    switch (k) {
        .up => {
            const y = self.getCurrentView().getCursor().y;
            if (y > 0) {
                const pos = self.getCurrentView().getBufferPopsition(.{ .x = self.getCurrentView().last_cursor_x, .y = y - 1 });
                for (self.buffer_selector.getCurrentBuffer().cursors.items) |*cursor| {
                    try cursor.setPosition(pos);
                }
            }
        },
        .down => {
            const y = self.getCurrentView().getCursor().y;
            if (y < self.getCurrentView().getNumberOfLines() - 1) {
                const pos = self.getCurrentView().getBufferPopsition(.{ .x = self.getCurrentView().last_cursor_x, .y = y + 1 });
                for (self.buffer_selector.getCurrentBuffer().cursors.items) |*cursor| {
                    try cursor.setPosition(pos);
                }
            }
        },
        .left => {
            for (self.buffer_selector.getCurrentBuffer().cursors.items) |*cursor| {
                try cursor.moveBackward();
            }
            self.getCurrentView().updateLastCursorX();
        },
        .right => {
            for (self.buffer_selector.getCurrentBuffer().cursors.items) |*cursor| {
                try cursor.moveForward();
            }
            self.getCurrentView().updateLastCursorX();
        },
    }
}

fn breakLine(self: *EditorController) !void {
    for (self.buffer_selector.getCurrentBuffer().cursors.items) |*cursor| {
        try self.buffer_selector.getCurrentBuffer().breakLine(cursor.getPosition());
        try cursor.moveForward();
    }
    self.getCurrentView().updateLastCursorX();
}

fn killLine(self: *EditorController) !void {
    for (self.buffer_selector.getCurrentBuffer().cursors.items) |*cursor| {
        try self.buffer_selector.getCurrentBuffer().killLine(cursor.getPosition());
    }
    self.getCurrentView().updateLastCursorX();
}

fn insertChar(self: *EditorController, char: u21) !void {
    try self.buffer_selector.getCurrentBuffer().insertChar(char);
    self.getCurrentView().updateLastCursorX();
}

fn getCurrentView(self: *const EditorController) *view.BufferView {
    return switch (self.buffer_selector.getCurrentBuffer().mode) {
        models.Buffer.Mode.file => self.file_buffer_view,
        models.Buffer.Mode.command => self.command_buffer_view,
    };
}

pub fn openFile(self: *EditorController, path: []const u8) !void {
    try self.buffer_selector.openFileBuffer(path);
    const new_message = try std.fmt.allocPrint(self.allocator, "{s}", .{path});
    errdefer self.allocator.free(new_message);
    try self.status_message.setMessage(new_message);
}
