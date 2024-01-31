const std = @import("std");
const Editor = @import("../Editor.zig");

test "no opened files" {
    var editor = try Editor.init(std.testing.allocator, .{});
    defer editor.deinit();
    try editor.controller.changeDisplaySize(10, 10);
    try editor.display.render();
    const area = try editor.display.getArea(0, 10, 0, 10);
    defer area.deinit();
    try area.expectEqualSlice(
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
        \\
    );
}

test "show the opened file" {
    var editor = try Editor.init(std.testing.allocator, .{});
    defer editor.deinit();
    try editor.controller.changeDisplaySize(100, 100);
    try editor.controller.openFile("src/e2e/hello-world.txt");
    try editor.display.render();
    const area = try editor.display.getArea(0, 1, 0, 11);
    defer area.deinit();
    try area.expectEqualSlice(
        \\Hello World
    );
}

test "open file via command" {
    var editor = try Editor.init(std.testing.allocator, .{});
    defer editor.deinit();
    try editor.controller.changeDisplaySize(100, 100);

    try editor.key_evaluator.evaluate(.{ .ctrl = 'X' });
    for ("files.open src/e2e/hello-world.txt") |c| {
        try editor.key_evaluator.evaluate(.{ .plain = c });
    }

    try editor.display.render();
    const footer_area = try editor.display.getArea(99, 100, 0, 40);
    defer footer_area.deinit();
    try footer_area.expectEqualSlice(
        \\files.open src/e2e/hello-world.txt
    );

    try editor.key_evaluator.evaluate(.{ .ctrl = 'M' });

    try editor.display.render();
    const top_area = try editor.display.getArea(0, 99, 0, 20);
    defer top_area.deinit();
    try top_area.expectEqualSlice(
        \\Hello World
    );
}
