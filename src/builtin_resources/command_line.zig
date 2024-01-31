const std = @import("std");
const Editor = @import("../Editor.zig");
const Resource = @import("../Resource.zig");
const TextView = @import("../TextView.zig");

pub fn init(allocator: std.mem.Allocator) !Resource {
    var command_line = Resource.init(allocator);
    errdefer command_line.deinit();
    try command_line.putMethod("toggle", toggle);
    return command_line;
}

fn toggle(editor: *Editor, _: [][]const u8) !void {
    try editor.client.toggleCommandLine();
}
