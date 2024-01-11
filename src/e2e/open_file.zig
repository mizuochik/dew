const std = @import("std");
const Editor = @import("../Editor.zig");

test "no opened files" {
    var editor = try Editor.init(std.testing.allocator, .{});
    defer editor.deinit();
    try editor.controller.changeDisplaySize(10, 10);
    try editor.display.render(&editor.client);
    const area = try editor.display.getArea(0, 10, 0, 10);
    defer area.deinit();
    try std.testing.expectEqualStrings("          ", area.rows[0]);
    try std.testing.expectEqualStrings("          ", area.rows[9]);
}

test "show the opened file" {
    var editor = try Editor.init(std.testing.allocator, .{});
    defer editor.deinit();
    try editor.controller.changeDisplaySize(100, 100);
    try editor.controller.openFile("src/e2e/hello-world.txt");
    try editor.display.render(&editor.client);
    const area = try editor.display.getArea(0, 1, 0, 11);
    defer area.deinit();
    try std.testing.expectEqualStrings("Hello World", area.rows[0]);
}

test "open file via command" {
    var editor = try Editor.init(std.testing.allocator, .{});
    defer editor.deinit();
    try editor.controller.changeDisplaySize(100, 100);

    try editor.controller.processKeypress(.{ .ctrl = 'X' });
    for ("open-file src/e2e/hello-world.txt") |c| {
        try editor.controller.processKeypress(.{ .plain = c });
    }

    try editor.display.render(&editor.client);
    const footer_area = try editor.display.getArea(99, 100, 0, 40);
    defer footer_area.deinit();
    try std.testing.expectEqualStrings("open-file src/e2e/hello-world.txt       ", footer_area.rows[0]);

    try editor.controller.processKeypress(.{ .ctrl = 'M' });

    try editor.display.render(&editor.client);
    const top_area = try editor.display.getArea(0, 99, 0, 20);
    defer top_area.deinit();
    try std.testing.expectEqualStrings("Hello World         ", top_area.rows[0]);
}
