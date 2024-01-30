const std = @import("std");
const Editor = @import("../Editor.zig");
const Resource = @import("../Resource.zig");
const TextView = @import("../TextView.zig");

pub fn init(allocator: std.mem.Allocator) !Resource {
    var views = Resource.init(allocator);
    errdefer views.deinit();
    try views.putMethod("scroll", scroll);
    return views;
}

fn scroll(editor: *Editor, params: [][]const u8) anyerror!void {
    if (params.len != 2) {
        {
            const message = try std.fmt.allocPrint(editor.allocator, "invalid argument length: want {} but {}", .{ 2, params.len });
            errdefer editor.allocator.free(message);
            try editor.client.status.setMessage(message);
        }
        return error.InvalidArguments;
    }
    const direction = params[1];
    var view = getCurrentView(editor);
    if (std.mem.eql(u8, direction, "up")) {
        view.scrollUp(editor.client.getActiveEdit().?, view.height);
        const buf_pos = view.getBufferPosition(editor.client.getActiveFile().?, view.getNormalizedCursor(editor.client.getActiveFile().?));
        const edit = editor.client.active_ref.?;
        try edit.cursor.setPosition(buf_pos);
        return;
    }
    if (std.mem.eql(u8, direction, "down")) {
        view.scrollDown(editor.client.getActiveEdit().?, view.height);
        const buf_pos = view.getBufferPosition(editor.client.getActiveFile().?, view.getNormalizedCursor(editor.client.getActiveFile().?));
        const edit = editor.client.active_ref.?;
        try edit.cursor.setPosition(buf_pos);
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
