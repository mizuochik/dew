const std = @import("std");
const Editor = @import("../Editor.zig");
const Resource = @import("../Resource.zig");
const TextView = @import("../TextView.zig");

pub fn init(allocator: std.mem.Allocator) !Resource {
    var cursors = Resource.init(allocator);
    errdefer cursors.deinit();
    try cursors.putMethod("break-line", breakLine);
    try cursors.putMethod("join-lines", joinLines);
    try cursors.putMethod("kill-line", killLine);
    try cursors.putMethod("delete-character", deleteCharacter);
    try cursors.putMethod("delete-backward-character", deleteBackwardCharacter);
    return cursors;
}

fn killLine(editor: *Editor, _: [][]const u8) !void {
    const edit = editor.client.active_ref.?;
    try edit.text.killLine(edit.cursor.getPosition());
    getCurrentView(editor).updateLastCursorX(editor.client.getActiveEdit().?);
}

fn breakLine(editor: *Editor, _: [][]const u8) !void {
    if (editor.client.isCommandLineActive()) {
        const command = editor.client.command_line.rows.items[0];
        try editor.command_evaluator.evaluate(command);
        try editor.client.toggleCommandLine();
        return;
    }
    const edit = editor.client.active_ref.?;
    try edit.text.breakLine(edit.cursor.getPosition());
    try edit.cursor.moveForward();
    getCurrentView(editor).updateLastCursorX(editor.client.getActiveEdit().?);
}

fn joinLines(editor: *Editor, _: [][]const u8) !void {
    const edit = editor.client.active_ref.?;
    try edit.text.joinLine(edit.cursor.getPosition());
}

fn deleteCharacter(editor: *Editor, _: [][]const u8) !void {
    const edit = editor.client.active_ref.?;
    try edit.text.deleteChar(edit.cursor.getPosition());
}

fn deleteBackwardCharacter(editor: *Editor, _: [][]const u8) !void {
    const edit = editor.client.active_ref.?;
    try edit.cursor.moveBackward();
    try edit.text.deleteChar(edit.cursor.getPosition());
}

fn getCurrentView(editor: *Editor) *TextView {
    return if (editor.client.isCommandLineActive())
        &editor.command_ref_view
    else
        &editor.edit_view;
}
