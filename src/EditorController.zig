const std = @import("std");
const view = @import("view.zig");
const models = @import("models.zig");
const Buffer = @import("Buffer.zig");
const BufferView = @import("BufferView.zig");
const DisplaySize = @import("DisplaySize.zig");
const Status = @import("Status.zig");
const BufferSelector = @import("BufferSelector.zig");
const Display = @import("Display.zig");
const Editor = @import("Editor.zig");
const Cursor = @import("Cursor.zig");

file_buffer_view: *BufferView,
command_buffer_view: *BufferView,
status: *Status,
file_path: ?[]const u8 = null,
buffer_selector: *BufferSelector,
display_size: *DisplaySize,
display: *Display,
allocator: std.mem.Allocator,
editor: *Editor,
cursors: [1]*Cursor,

const EditorController = @This();

pub fn init(allocator: std.mem.Allocator, file_buffer_view: *BufferView, command_buffer_view: *BufferView, status: *Status, buffer_selector: *BufferSelector, display: *Display, display_size: *DisplaySize, editor: *Editor) !EditorController {
    return EditorController{
        .allocator = allocator,
        .file_buffer_view = file_buffer_view,
        .command_buffer_view = command_buffer_view,
        .status = status,
        .buffer_selector = buffer_selector,
        .display = display,
        .display_size = display_size,
        .editor = editor,
        .cursors = .{undefined},
    };
}

pub fn deinit(_: *const EditorController) void {}

pub fn processKeypress(self: *EditorController, key: models.Key) !void {
    switch (key) {
        .del => {
            for (self.getCursors()) |cursor| {
                try cursor.moveBackward();
                try self.buffer_selector.getCurrentBuffer().deleteChar(cursor.getPosition());
            }
        },
        .ctrl => |k| switch (k) {
            'Q' => return error.Quit,
            'S' => try self.buffer_selector.saveFileBuffer(self.editor.client.current_file.?),
            'K' => try self.killLine(),
            'D' => {
                for (self.getCursors()) |cursor| {
                    try self.buffer_selector.getCurrentBuffer().deleteChar(cursor.getPosition());
                }
            },
            'H' => {
                for (self.getCursors()) |cursor| {
                    try cursor.moveBackward();
                    try self.buffer_selector.getCurrentBuffer().deleteChar(cursor.getPosition());
                }
            },
            'M' => if (self.buffer_selector.is_command_buffer_active) {
                const command = self.editor.buffer_selector.getCommandLine().rows.items[0];
                try self.editor.command_evaluator.evaluate(command);
            } else {
                try self.breakLine();
            },
            'P' => try self.moveCursor(.up),
            'N' => try self.moveCursor(.down),
            'F' => try self.moveCursor(.right),
            'B' => try self.moveCursor(.left),
            'J' => {
                for (self.getCursors()) |cursor| {
                    try self.buffer_selector.getCurrentBuffer().joinLine(cursor.getPosition());
                }
            },
            'A' => {
                for (self.getCursors()) |cursor| {
                    try cursor.moveToBeginningOfLine();
                }
                self.getCurrentView().updateLastCursorX();
            },
            'E' => {
                for (self.getCursors()) |cursor| {
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
                for (self.getCursors()) |cursor| {
                    try cursor.setPosition(buf_pos);
                }
            },
            else => {},
        },
        .meta => |k| switch (k) {
            'v' => {
                self.getCurrentView().scrollUp(self.getCurrentView().height);
                const buf_pos = self.getCurrentView().getBufferPopsition(self.getCurrentView().getNormalizedCursor());
                for (self.getCursors()) |cursor| {
                    try cursor.setPosition(buf_pos);
                }
            },
            else => {},
        },
        .plain => |k| {
            for (self.getCursors()) |cursor| {
                try self.buffer_selector.getCurrentBuffer().insertChar(cursor.getPosition(), k);
                try cursor.moveForward();
            }
        },
        .arrow => |k| try self.moveCursor(k),
    }
}

pub fn changeDisplaySize(self: *const EditorController, cols: usize, rows: usize) !void {
    try self.display.changeSize(&.{ .cols = @intCast(cols), .rows = @intCast(rows) });
}

fn moveCursor(self: *EditorController, k: models.Arrow) !void {
    switch (k) {
        .up => {
            const y = self.getCurrentView().getCursor().y;
            if (y > 0) {
                const pos = self.getCurrentView().getBufferPopsition(.{ .x = self.getCurrentView().last_cursor_x, .y = y - 1 });
                for (self.getCursors()) |cursor| {
                    try cursor.setPosition(pos);
                }
            }
        },
        .down => {
            const y = self.getCurrentView().getCursor().y;
            if (y < self.getCurrentView().getNumberOfLines() - 1) {
                const pos = self.getCurrentView().getBufferPopsition(.{ .x = self.getCurrentView().last_cursor_x, .y = y + 1 });
                for (self.getCursors()) |cursor| {
                    try cursor.setPosition(pos);
                }
            }
        },
        .left => {
            for (self.getCursors()) |cursor| {
                try cursor.moveBackward();
            }
            self.getCurrentView().updateLastCursorX();
        },
        .right => {
            for (self.getCursors()) |cursor| {
                try cursor.moveForward();
            }
            self.getCurrentView().updateLastCursorX();
        },
    }
}

fn breakLine(self: *EditorController) !void {
    for (self.getCursors()) |cursor| {
        try self.buffer_selector.getCurrentBuffer().breakLine(cursor.getPosition());
        try cursor.moveForward();
    }
    self.getCurrentView().updateLastCursorX();
}

fn killLine(self: *EditorController) !void {
    for (self.getCursors()) |cursor| {
        try self.buffer_selector.getCurrentBuffer().killLine(cursor.getPosition());
    }
    self.getCurrentView().updateLastCursorX();
}

fn insertChar(self: *EditorController, char: u21) !void {
    try self.buffer_selector.getCurrentBuffer().insertChar(char);
    self.getCurrentView().updateLastCursorX();
}

fn getCurrentView(self: *const EditorController) *BufferView {
    return if (self.buffer_selector.is_command_buffer_active)
        self.command_buffer_view
    else
        self.file_buffer_view;
}

pub fn openFile(self: *EditorController, path: []const u8) !void {
    try self.buffer_selector.openFileBuffer(path);
    const new_message = try std.fmt.allocPrint(self.allocator, "{s}", .{path});
    errdefer self.allocator.free(new_message);
    try self.status.setMessage(new_message);
}

fn getCursors(self: *EditorController) []*Cursor {
    self.cursors[0] = if (self.buffer_selector.is_command_buffer_active)
        &self.editor.client.command_cursor
    else
        self.editor.client.getActiveCursor();
    // self.cursors[0] = &self.buffer_selector.getCurrentBuffer().cursors.items[0];
    return &self.cursors;
}
