const std = @import("std");
const Editor = @import("../Editor.zig");

test "show the opened file" {
    var editor = try Editor.init(std.testing.allocator, .{});
    defer editor.deinit();
    try editor.controller.changeDisplaySize(100, 100);
    try editor.controller.openFile("src/e2e/hello-world.txt");
    const area = try editor.display.getArea(0, 1, 0, 11);
    defer area.deinit();
    try std.testing.expectEqualStrings("Hello World", area.rows[0]);
}

test "open new file" {
    var editor = try Editor.init(std.testing.allocator, .{});
    defer editor.deinit();
    try editor.controller.changeDisplaySize(100, 100);

    // Open a file first
    try editor.controller.openFile("src/e2e/hello-world.txt");

    try editor.controller.processKeypress(.{ .ctrl = 'X' });
    for ("new-file") |c| {
        try editor.controller.processKeypress(.{ .plain = c });
    }
    try editor.controller.processKeypress(.{ .ctrl = 'M' });

    const top_area = try editor.display.getArea(0, 99, 0, 20);
    defer top_area.deinit();
    try std.testing.expectEqualStrings("                    ", top_area.rows[0]);
}
