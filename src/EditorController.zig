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
