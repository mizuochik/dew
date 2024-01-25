const std = @import("std");
const Editor = @import("../Editor.zig");
const Resource = @import("../Resource.zig");

pub fn init(allocator: std.mem.Allocator) !Resource {
    var files = Resource.init(allocator);
    errdefer files.deinit();
    try files.putMethod("new", new);
    try files.putMethod("open", open);
    try files.putMethod("save", save);
    return files;
}

fn new(editor: *Editor, params: [][]const u8) anyerror!void {
    const want_params_len = 0;
    if (params.len != want_params_len) {
        const message = try std.fmt.allocPrint(editor.allocator, "invalid argument length: want {d} but {d}", .{ want_params_len, params.len });
        errdefer editor.allocator.free(message);
        try editor.client.status.setMessage(message);
        return;
    }
    const untitled_name = try std.fmt.allocPrint(editor.allocator, "Untitled", .{});
    defer editor.allocator.free(untitled_name);
    try editor.buffer_selector.openFileBuffer(untitled_name);
}

fn open(editor: *Editor, params: [][]const u8) anyerror!void {
    const want_params_len = 1;
    if (params.len != want_params_len) {
        const message = try std.fmt.allocPrint(editor.allocator, "invalid argument length: want {d} but {d}", .{ want_params_len, params.len });
        errdefer editor.allocator.free(message);
        try editor.client.status.setMessage(message);
        return;
    }
    const file_path = params[0];
    try editor.buffer_selector.openFileBuffer(file_path);
}

fn save(editor: *Editor, params: [][]const u8) anyerror!void {
    const want_params_max_len = 1;
    if (params.len > want_params_max_len) {
        const message = try std.fmt.allocPrint(editor.allocator, "invalid argument length: want <= {} but {d}", .{ want_params_max_len, params.len });
        errdefer editor.allocator.free(message);
        try editor.client.status.setMessage(message);
        return;
    }
    const file_name = switch (params.len) {
        0 => editor.client.current_file.?,
        1 => params[0],
        else => {
            const message = try std.fmt.allocPrint(editor.allocator, "invalid argument length: want <= 1 but {d}", .{params.len});
            errdefer editor.allocator.free(message);
            try editor.client.status.setMessage(message);
            return;
        },
    };
    try editor.buffer_selector.saveFileBuffer(file_name);
}
