const std = @import("std");
const heap = std.heap;
const debug = std.debug;
const Editor = @import("Editor.zig");

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var editor = try Editor.init(allocator);
    defer editor.deinit() catch unreachable;

    try editor.run();
}

test {
    _ = Editor;
}
