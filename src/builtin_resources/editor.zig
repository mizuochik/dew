const std = @import("std");
const Editor = @import("../Editor.zig");
const Resource = @import("../Resource.zig");

pub fn init(allocator: std.mem.Allocator) !Resource {
    var editor = Resource.init(allocator);
    errdefer editor.deinit();
    try editor.putMethod("quit", quit);
    return editor;
}

fn quit(_: *Editor, _: [][]const u8) anyerror!void {
    return error.Quit;
}
