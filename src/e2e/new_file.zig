const std = @import("std");
const Editor = @import("../Editor.zig");

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

test "open new file" {
    var editor = try Editor.init(std.testing.allocator, .{});
    defer editor.deinit();
    try editor.controller.changeDisplaySize(100, 100);

    // Open a file first
    try editor.controller.openFile("src/e2e/hello-world.txt");

    try editor.key_evaluator.evaluate(.{ .ctrl = 'X' });
    for ("files.new") |c| {
        try editor.key_evaluator.evaluate(.{ .plain = c });
    }
    try editor.key_evaluator.evaluate(.{ .ctrl = 'M' });

    try editor.display.render();
    const top_area = try editor.display.getArea(0, 99, 0, 20);
    defer top_area.deinit();
    try top_area.expectEqualSlice(
        \\
    );
}
