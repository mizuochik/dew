const std = @import("std");
const Editor = @import("../Editor.zig");
const Resource = @import("../Resource.zig");
const TextView = @import("../TextView.zig");

pub fn init(allocator: std.mem.Allocator) !Resource {
    var command_line = Resource.init(allocator);
    errdefer command_line.deinit();
    try command_line.putMethod("toggle", toggle);
    try command_line.putMethod("put", put);
    return command_line;
}

fn toggle(editor: *Editor, _: [][]const u8) !void {
    try editor.client.toggleCommandLine();
}

fn put(editor: *Editor, params: [][]const u8) !void {
    const want_params_len = 1;
    if (params.len != want_params_len) {
        const message = try std.fmt.allocPrint(editor.allocator, "invalid argument length: want {d} but {d}", .{ want_params_len, params.len });
        errdefer editor.allocator.free(message);
        try editor.client.status.setMessage(message);
        return;
    }
    if (!editor.client.isCommandLineActive())
        try editor.client.toggleCommandLine();
    try editor.client.command_line.clear();
    try editor.client.command_line.rows.items[0].appendSlice(params[0]);
}
