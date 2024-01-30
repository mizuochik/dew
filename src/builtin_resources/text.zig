const std = @import("std");
const Editor = @import("../Editor.zig");
const Resource = @import("../Resource.zig");
const TextView = @import("../TextView.zig");

pub fn init(allocator: std.mem.Allocator) !Resource {
    var cursors = Resource.init(allocator);
    errdefer cursors.deinit();
    try cursors.putMethod("kill-line", killLine);
    return cursors;
}

fn killLine(editor: *Editor, _: [][]const u8) !void {
    const edit = editor.client.active_ref.?;
    try edit.text.killLine(edit.cursor.getPosition());
    getCurrentView(editor).updateLastCursorX(editor.client.getActiveEdit().?);
}

fn getCurrentView(editor: *Editor) *TextView {
    return if (editor.client.isCommandLineActive())
        &editor.command_ref_view
    else
        &editor.edit_view;
}
