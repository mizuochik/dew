const std = @import("std");
const heap = std.heap;
const os = std.os;
const fmt = std.fmt;
const io = std.io;
const time = std.time;
const debug = std.debug;
const mem = std.mem;
const Editor = @import("Editor.zig");

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    if (os.argv.len < 2) {
        try io.getStdErr().writer().print("Specify file\n", .{});
        os.exit(1);
    }
    const path: []const u8 = mem.span(os.argv[1]);

    var editor = try Editor.init(allocator);
    defer editor.deinit() catch unreachable;

    try editor.openFile(path);
    try editor.run();
}

test {
    _ = Editor;
}
