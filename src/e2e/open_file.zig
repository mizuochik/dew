const std = @import("std");
const Editor = @import("../Editor.zig");

test "no opened files" {
    var editor = try Editor.init(std.testing.allocator);
    defer editor.deinit();
    try editor.controller.changeDisplaySize(10, 10);
    const area = try editor.display.getArea(0, 10, 0, 10);
    defer area.deinit();
    try std.testing.expectEqualStrings("          ", area.rows[0]);
    try std.testing.expectEqualStrings("          ", area.rows[9]);
}

test "show the opened file" {
    var editor = try Editor.init(std.testing.allocator);
    defer editor.deinit();
    try editor.controller.changeDisplaySize(100, 100);
    try editor.controller.openFile("src/e2e/hello-world.txt");
    const area = try editor.display.getArea(0, 1, 0, 11);
    defer area.deinit();
    try std.testing.expectEqualStrings("Hello World", area.rows[0]);
}
