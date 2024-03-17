const std = @import("std");
const Editor = @import("../Editor.zig");
const Resource = @import("../Resource.zig");
const TextView = @import("../TextView.zig");

pub fn init(allocator: std.mem.Allocator) !Resource {
    var selections = Resource.init(allocator);
    errdefer selections.deinit();
    try selections.putMethod("break-line", breakLine);
    try selections.putMethod("join-lines", joinLines);
    try selections.putMethod("kill-line", killLine);
    try selections.putMethod("delete-character", deleteCharacter);
    try selections.putMethod("delete-backward-character", deleteBackwardCharacter);
    return selections;
}

fn killLine(editor: *Editor, _: [][]const u8) !void {
    const edit = editor.client.active_ref.?;
    try edit.text.killLine(edit.selection.getPosition());
    getCurrentView(editor).updateLastSelectionX(editor.client.getActiveEdit().?);
}

fn breakLine(editor: *Editor, _: [][]const u8) !void {
    if (editor.client.isCommandLineActive()) {
        const command = editor.client.command_line.rows.items[0];
        try editor.command_evaluator.evaluate(command);
        try editor.client.toggleCommandLine();
        return;
    }
    const edit = editor.client.active_ref.?;
    try edit.text.breakLine(edit.selection.getPosition());
    try edit.selection.moveForward();
    getCurrentView(editor).updateLastSelectionX(editor.client.getActiveEdit().?);
}

fn joinLines(editor: *Editor, _: [][]const u8) !void {
    const edit = editor.client.active_ref.?;
    try edit.text.joinLine(edit.selection.getPosition());
}

fn deleteCharacter(editor: *Editor, _: [][]const u8) !void {
    const edit = editor.client.active_ref.?;
    try edit.text.deleteChar(edit.selection.getPosition());
}

fn deleteBackwardCharacter(editor: *Editor, _: [][]const u8) !void {
    const edit = editor.client.active_ref.?;
    try edit.selection.moveBackward();
    try edit.text.deleteChar(edit.selection.getPosition());
}

fn getCurrentView(editor: *Editor) *TextView {
    return if (editor.client.isCommandLineActive())
        &editor.command_ref_view
    else
        &editor.edit_view;
}
