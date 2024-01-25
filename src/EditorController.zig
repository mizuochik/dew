const std = @import("std");
const Text = @import("Text.zig");
const EditView = @import("EditView.zig");
const DisplaySize = @import("DisplaySize.zig");
const Status = @import("Status.zig");
const BufferSelector = @import("BufferSelector.zig");
const Display = @import("Display.zig");
const Editor = @import("Editor.zig");
const Cursor = @import("Cursor.zig");
const Keyboard = @import("Keyboard.zig");

file_edit_view: *EditView,
method_edit_view: *EditView,
file_path: ?[]const u8 = null,
buffer_selector: *BufferSelector,
display_size: *DisplaySize,
display: *Display,
allocator: std.mem.Allocator,
editor: *Editor,
cursors: [1]*Cursor,

pub fn init(allocator: std.mem.Allocator, file_edit_view: *EditView, method_edit_view: *EditView, buffer_selector: *BufferSelector, display: *Display, display_size: *DisplaySize, editor: *Editor) !@This() {
    return @This(){
        .allocator = allocator,
        .file_edit_view = file_edit_view,
        .method_edit_view = method_edit_view,
        .buffer_selector = buffer_selector,
        .display = display,
        .display_size = display_size,
        .editor = editor,
        .cursors = .{undefined},
    };
}

pub fn deinit(_: *const @This()) void {}

pub fn processKeypress(self: *@This(), key: Keyboard.Key) !void {
    switch (key) {
        .del => {
            const edit = self.editor.client.active_edit.?;
            try edit.cursor.moveBackward();
            try edit.text.deleteChar(edit.cursor.getPosition());
        },
        .ctrl => |k| switch (k) {
            'Q' => return error.Quit,
            'S' => try self.buffer_selector.saveFileBuffer(self.editor.client.current_file.?),
            'K' => try self.killLine(),
            'D' => {
                const edit = self.editor.client.active_edit.?;
                try edit.text.deleteChar(edit.cursor.getPosition());
            },
            'H' => {
                const edit = self.editor.client.active_edit.?;
                try edit.cursor.moveBackward();
                try edit.text.deleteChar(edit.cursor.getPosition());
            },
            'M' => if (self.editor.client.is_method_line_active) {
                const command = self.editor.client.method_line.rows.items[0];
                try self.editor.method_evaluator.evaluate(command);
            } else {
                try self.breakLine();
            },
            'P' => try self.moveCursor(.up),
            'N' => try self.moveCursor(.down),
            'F' => try self.moveCursor(.right),
            'B' => try self.moveCursor(.left),
            'J' => {
                const edit = self.editor.client.active_edit.?;
                try edit.text.joinLine(edit.cursor.getPosition());
            },
            'A' => {
                const edit = self.editor.client.active_edit.?;
                try edit.cursor.moveToBeginningOfLine();
                self.getCurrentView().updateLastCursorX(self.editor.client.getActiveEdit().?);
            },
            'E' => {
                const edit = self.editor.client.active_edit.?;
                try edit.cursor.moveToEndOfLine();
                self.getCurrentView().updateLastCursorX(self.editor.client.getActiveEdit().?);
            },
            'X' => {
                try self.editor.client.toggleMethodLine();
            },
            'V' => {
                self.getCurrentView().scrollDown(self.editor.client.getActiveEdit().?, self.getCurrentView().height);
                const buf_pos = self.getCurrentView().getBufferPosition(self.editor.client.getActiveFile().?, self.getCurrentView().getNormalizedCursor(self.editor.client.getActiveFile().?));
                const edit = self.editor.client.active_edit.?;
                try edit.cursor.setPosition(buf_pos);
            },
            else => {},
        },
        .meta => |k| switch (k) {
            'v' => {
                self.getCurrentView().scrollUp(self.editor.client.getActiveEdit().?, self.getCurrentView().height);
                const buf_pos = self.getCurrentView().getBufferPosition(self.editor.client.getActiveFile().?, self.getCurrentView().getNormalizedCursor(self.editor.client.getActiveFile().?));
                const edit = self.editor.client.active_edit.?;
                try edit.cursor.setPosition(buf_pos);
            },
            else => {},
        },
        .plain => |k| {
            const edit = self.editor.client.active_edit.?;
            try edit.text.insertChar(edit.cursor.getPosition(), k);
            try edit.cursor.moveForward();
        },
        .arrow => |k| try self.moveCursor(k),
    }
}

pub fn changeDisplaySize(self: *const @This(), cols: usize, rows: usize) !void {
    try self.display.changeSize(&.{ .cols = @intCast(cols), .rows = @intCast(rows) });
}

fn moveCursor(self: *@This(), k: Keyboard.Arrow) !void {
    switch (k) {
        .up => {
            const y = self.getCurrentView().getCursor(self.editor.client.getActiveEdit().?).y;
            if (y > 0) {
                var edit = self.editor.client.getActiveEdit().?;
                const pos = self.getCurrentView().getBufferPosition(edit, .{ .x = edit.cursor.last_view_x, .y = y - 1 });
                try edit.cursor.setPosition(pos);
            }
        },
        .down => {
            const y = self.getCurrentView().getCursor(self.editor.client.getActiveEdit().?).y;
            if (y < self.getCurrentView().getNumberOfLines() - 1) {
                const edit = self.editor.client.active_edit.?;
                const pos = self.getCurrentView().getBufferPosition(edit, .{ .x = edit.cursor.last_view_x, .y = y + 1 });
                try edit.cursor.setPosition(pos);
            }
        },
        .left => {
            const edit = self.editor.client.active_edit.?;
            try edit.cursor.moveBackward();
            self.getCurrentView().updateLastCursorX(self.editor.client.getActiveEdit().?);
        },
        .right => {
            const edit = self.editor.client.active_edit.?;
            try edit.cursor.moveForward();
            self.getCurrentView().updateLastCursorX(self.editor.client.getActiveEdit().?);
        },
    }
}

fn breakLine(self: *@This()) !void {
    const edit = self.editor.client.active_edit.?;
    try edit.text.breakLine(edit.cursor.getPosition());
    try edit.cursor.moveForward();
    self.getCurrentView().updateLastCursorX(self.editor.client.getActiveEdit().?);
}

fn killLine(self: *@This()) !void {
    const edit = self.editor.client.active_edit.?;
    try edit.text.killLine(edit.cursor.getPosition());
    self.getCurrentView().updateLastCursorX(self.editor.client.getActiveEdit().?);
}

fn getCurrentView(self: *const @This()) *EditView {
    return if (self.editor.client.is_method_line_active)
        self.method_edit_view
    else
        self.file_edit_view;
}

pub fn openFile(self: *@This(), path: []const u8) !void {
    try self.buffer_selector.openFileBuffer(path);
    const new_message = try std.fmt.allocPrint(self.allocator, "{s}", .{path});
    errdefer self.allocator.free(new_message);
    try self.editor.client.status.setMessage(new_message);
}
