const std = @import("std");
const Text = @import("Text.zig");
const TextView = @import("TextView.zig");
const DisplaySize = @import("DisplaySize.zig");
const Status = @import("Status.zig");
const BufferSelector = @import("BufferSelector.zig");
const Display = @import("Display.zig");
const Editor = @import("Editor.zig");
const Cursor = @import("Cursor.zig");
const Keyboard = @import("Keyboard.zig");
const UnicodeString = @import("UnicodeString.zig");

file_view: *TextView,
command_ref_view: *TextView,
file_path: ?[]const u8 = null,
buffer_selector: *BufferSelector,
display_size: *DisplaySize,
display: *Display,
allocator: std.mem.Allocator,
editor: *Editor,
cursors: [1]*Cursor,

pub fn init(allocator: std.mem.Allocator, file_view: *TextView, command_ref_view: *TextView, buffer_selector: *BufferSelector, display: *Display, display_size: *DisplaySize, editor: *Editor) !@This() {
    return @This(){
        .allocator = allocator,
        .file_view = file_view,
        .command_ref_view = command_ref_view,
        .buffer_selector = buffer_selector,
        .display = display,
        .display_size = display_size,
        .editor = editor,
        .cursors = .{undefined},
    };
}

pub fn deinit(_: *const @This()) void {}

pub fn processKeypress(self: *@This(), key: Keyboard.Key) !void {
    if (self.editor.key_evaluator.evaluate(key)) |methods| {
        for (methods) |method| {
            var u_method = try UnicodeString.init(self.allocator);
            defer u_method.deinit();
            try u_method.appendSlice(method);
            self.editor.command_evaluator.evaluate(u_method) catch |e| switch (e) {
                error.InvalidArguments => break,
                else => return e,
            };
        }
    } else |err| switch (err) {
        error.NoKeyMap => switch (key) {
            .del => {
                const edit = self.editor.client.active_ref.?;
                try edit.cursor.moveBackward();
                try edit.text.deleteChar(edit.cursor.getPosition());
            },
            .ctrl => |k| switch (k) {
                'S' => try self.buffer_selector.saveFileBuffer(self.editor.client.current_file.?),
                'K' => try self.killLine(),
                'D' => {
                    const edit = self.editor.client.active_ref.?;
                    try edit.text.deleteChar(edit.cursor.getPosition());
                },
                'H' => {
                    const edit = self.editor.client.active_ref.?;
                    try edit.cursor.moveBackward();
                    try edit.text.deleteChar(edit.cursor.getPosition());
                },
                'M' => if (self.editor.client.is_command_line_active) {
                    const command = self.editor.client.command_line.rows.items[0];
                    try self.editor.command_evaluator.evaluate(command);
                    try self.editor.client.toggleCommandLine();
                } else {
                    try self.breakLine();
                },
                'J' => {
                    const edit = self.editor.client.active_ref.?;
                    try edit.text.joinLine(edit.cursor.getPosition());
                },
                'X' => {
                    try self.editor.client.toggleCommandLine();
                },
                else => {},
            },
            .plain => |k| {
                const edit = self.editor.client.active_ref.?;
                try edit.text.insertChar(edit.cursor.getPosition(), k);
                try edit.cursor.moveForward();
            },
            else => {},
        },
        else => return err,
    }
}

pub fn changeDisplaySize(self: *const @This(), cols: usize, rows: usize) !void {
    try self.display.changeSize(&.{ .cols = @intCast(cols), .rows = @intCast(rows) });
}

fn breakLine(self: *@This()) !void {
    const edit = self.editor.client.active_ref.?;
    try edit.text.breakLine(edit.cursor.getPosition());
    try edit.cursor.moveForward();
    self.getCurrentView().updateLastCursorX(self.editor.client.getActiveEdit().?);
}

fn killLine(self: *@This()) !void {
    const edit = self.editor.client.active_ref.?;
    try edit.text.killLine(edit.cursor.getPosition());
    self.getCurrentView().updateLastCursorX(self.editor.client.getActiveEdit().?);
}

fn getCurrentView(self: *const @This()) *TextView {
    return if (self.editor.client.is_command_line_active)
        self.command_ref_view
    else
        self.file_view;
}

pub fn openFile(self: *@This(), path: []const u8) !void {
    try self.buffer_selector.openFileBuffer(path);
    const new_message = try std.fmt.allocPrint(self.allocator, "{s}", .{path});
    errdefer self.allocator.free(new_message);
    try self.editor.client.status.setMessage(new_message);
}
