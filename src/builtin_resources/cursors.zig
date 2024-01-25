const std = @import("std");
const Editor = @import("../Editor.zig");
const Resource = @import("../Resource.zig");
const EditView = @import("../EditView.zig");

pub fn init(allocator: std.mem.Allocator) !Resource {
    var cursors = Resource.init(allocator);
    errdefer cursors.deinit();
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
    if (std.mem.eql(u8, location, "next-character")) {
        try edit.cursor.moveForward();
        return;
    }
    if (std.mem.eql(u8, location, "previous-character")) {
        try edit.cursor.moveBackward();
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
    }
    if (std.mem.eql(u8, location, "previous-line")) {
        if (view_y <= 0) {
            return;
        }
        const pos = view.getBufferPosition(edit, .{ .x = edit.cursor.last_view_x, .y = view_y - 1 });
        try edit.cursor.setPosition(pos);
    }
}

fn getCurrentView(editor: *Editor) *EditView {
    return if (editor.client.is_method_line_active)
        editor.method_edit_view
    else
        editor.edit_view;
}
