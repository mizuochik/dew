const std = @import("std");
const Editor = @import("Editor.zig");

pub fn new_file(editor: *Editor, arguments: [][]const u8) anyerror!void {
    const want_arguments_len = 0;
    if (arguments.len != want_arguments_len) {
        const message = try std.fmt.allocPrint(editor.allocator, "invalid argument length: want {d} but {d}", .{ want_arguments_len, arguments.len });
        errdefer editor.allocator.free(message);
        try editor.client.status.setMessage(message);
        return;
    }
    const untitled_name = try std.fmt.allocPrint(editor.allocator, "Untitled", .{});
    defer editor.allocator.free(untitled_name);
    try editor.buffer_selector.openFileBuffer(untitled_name);
}

pub fn open_file(editor: *Editor, arguments: [][]const u8) anyerror!void {
    const want_arguments_len = 1;
    if (arguments.len != want_arguments_len) {
        const message = try std.fmt.allocPrint(editor.allocator, "invalid argument length: want {d} but {d}", .{ want_arguments_len, arguments.len });
        errdefer editor.allocator.free(message);
        try editor.client.status.setMessage(message);
        return;
    }
    const file_path = arguments[0];
    try editor.buffer_selector.openFileBuffer(file_path);
}

pub fn save_file(editor: *Editor, arguments: [][]const u8) anyerror!void {
    const want_arguments_max_len = 1;
    if (arguments.len > want_arguments_max_len) {
        const message = try std.fmt.allocPrint(editor.allocator, "invalid argument length: want <= {} but {d}", .{ want_arguments_max_len, arguments.len });
        errdefer editor.allocator.free(message);
        try editor.client.status.setMessage(message);
        return;
    }
    const file_name = switch (arguments.len) {
        0 => editor.client.current_file.?,
        1 => arguments[0],
        else => {
            const message = try std.fmt.allocPrint(editor.allocator, "invalid argument length: want <= 1 but {d}", .{arguments.len});
            errdefer editor.allocator.free(message);
            try editor.client.status.setMessage(message);
            return;
        },
    };
    try editor.buffer_selector.saveFileBuffer(file_name);
}
