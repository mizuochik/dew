const std = @import("std");
const Editor = @import("../Editor.zig");
const Resource = @import("../Resource.zig");
const TextView = @import("../TextView.zig");

pub fn init(allocator: std.mem.Allocator) !Resource {
    var cursors = Resource.init(allocator);
    errdefer cursors.deinit();
    try cursors.putMethod("move-to", moveTo);
    return cursors;
}

fn moveTo(editor: *Editor, params: [][]const u8) anyerror!void {
    if (params.len != 1) {
        const message = try std.fmt.allocPrint(editor.allocator, "invalid argument length: want {} but {}", .{ 1, params.len });
        errdefer editor.allocator.free(message);
        try editor.client.status.setMessage(message);
        return error.InvalidArguments;
    }
    const location = params[0];
    var edit = editor.client.getActiveEdit() orelse return;
    if (std.mem.eql(u8, location, "forward-character")) {
        try edit.cursor.moveForward();
        getCurrentView(editor).updateLastCursorX(editor.client.getActiveEdit().?);
        return;
    }
    if (std.mem.eql(u8, location, "backward-character")) {
        try edit.cursor.moveBackward();
        getCurrentView(editor).updateLastCursorX(editor.client.getActiveEdit().?);
        return;
    }
    const view = getCurrentView(editor);
    const view_y = view.getCursor(edit).y;
    if (std.mem.eql(u8, location, "next-line")) {
        if (view_y >= view.getNumberOfLines() - 1) {
            return;
        }
        const pos = view.getBufferPosition(edit, .{ .x = edit.cursor.last_view_x, .y = view_y + 1 });
        try edit.cursor.setPosition(pos);
        return;
    }
    if (std.mem.eql(u8, location, "previous-line")) {
        if (view_y <= 0) {
            return;
        }
        const pos = view.getBufferPosition(edit, .{ .x = edit.cursor.last_view_x, .y = view_y - 1 });
        try edit.cursor.setPosition(pos);
        return;
    }
    if (std.mem.eql(u8, location, "beginning-of-line")) {
        try edit.cursor.moveToBeginningOfLine();
        return;
    }
    if (std.mem.eql(u8, location, "end-of-line")) {
        try edit.cursor.moveToEndOfLine();
        return;
    }
    return error.UnknownLocation;
}

fn getCurrentView(editor: *Editor) *TextView {
    return if (editor.client.isCommandLineActive())
        &editor.command_ref_view
    else
        &editor.edit_view;
}
