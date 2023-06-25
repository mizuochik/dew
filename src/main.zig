const std = @import("std");
const heap = std.heap;
const debug = std.debug;
const Editor = @import("Editor.zig");

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var editor = Editor{
        .allocator = allocator,
        .config = null,
    };
    try editor.run();
}

test {
    _ = Editor;
}
