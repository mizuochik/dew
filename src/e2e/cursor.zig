const std = @import("std");
const Editor = @import("../Editor.zig");
const models = @import("../models.zig");

test "move cursor to any directions" {
    const editor = try Editor.init(std.testing.allocator);
    defer editor.deinit();
    try editor.controller.changeDisplaySize(100, 100);
    const cursor = &editor.controller.buffer_selector.getFileBuffer().cursors.items[0];
    try editor.buffer_selector.getFileBuffer().openFile("src/e2e/100x100.txt");

    try std.testing.expectEqualDeep(models.Position{ .x = 0, .y = 0 }, cursor.getPosition());

    for (0..5) |_| try editor.controller.processKeypress(.{ .arrow = .right });
    try std.testing.expectEqualDeep(models.Position{ .x = 5, .y = 0 }, cursor.getPosition());

    for (0..5) |_| try editor.controller.processKeypress(.{ .arrow = .down });
    try std.testing.expectEqualDeep(models.Position{ .x = 5, .y = 5 }, cursor.getPosition());

    for (0..4) |_| try editor.controller.processKeypress(.{ .arrow = .left });
    try std.testing.expectEqualDeep(models.Position{ .x = 1, .y = 5 }, cursor.getPosition());

    for (0..4) |_| try editor.controller.processKeypress(.{ .arrow = .up });
    try std.testing.expectEqualDeep(models.Position{ .x = 1, .y = 1 }, cursor.getPosition());
}

test "move to the beginning or end of line" {
    const editor = try Editor.init(std.testing.allocator);
    defer editor.deinit();
    try editor.controller.changeDisplaySize(100, 100);
    const cursor = &editor.controller.buffer_selector.getFileBuffer().cursors.items[0];
    try editor.buffer_selector.getFileBuffer().openFile("src/e2e/100x100.txt");

    for (0..10) |_| try cursor.moveForward();
    try std.testing.expectEqualDeep(models.Position{ .x = 10, .y = 0 }, cursor.getPosition());
    try editor.controller.processKeypress(.{ .ctrl = 'A' });
    try std.testing.expectEqualDeep(models.Position{ .x = 0, .y = 0 }, cursor.getPosition());

    for (0..10) |_| try cursor.moveForward();
    try std.testing.expectEqualDeep(models.Position{ .x = 10, .y = 0 }, cursor.getPosition());
    try editor.controller.processKeypress(.{ .ctrl = 'E' });
    try std.testing.expectEqualDeep(models.Position{ .x = 100, .y = 0 }, cursor.getPosition());
}

test "move vertically considering double bytes" {
    {
        const editor = try Editor.init(std.testing.allocator);
        defer editor.deinit();
        try editor.controller.changeDisplaySize(100, 100);
        const cursor = &editor.controller.buffer_selector.getFileBuffer().cursors.items[0];
        try editor.buffer_selector.getFileBuffer().openFile("src/e2e/mixed-byte-lines.txt");

        // Move to first half of double byte character
        for (0..4) |_| try editor.controller.processKeypress(.{ .arrow = .right });
        try std.testing.expectEqual(models.Position{ .x = 4, .y = 0 }, cursor.getPosition());
        try editor.controller.processKeypress(.{ .arrow = .down });
        try std.testing.expectEqual(models.Position{ .x = 2, .y = 1 }, cursor.getPosition());
        try editor.controller.processKeypress(.{ .arrow = .up });
        try std.testing.expectEqual(models.Position{ .x = 4, .y = 0 }, cursor.getPosition());
    }
    {
        const editor = try Editor.init(std.testing.allocator);
        defer editor.deinit();
        try editor.controller.changeDisplaySize(100, 100);
        const cursor = &editor.controller.buffer_selector.getFileBuffer().cursors.items[0];
        try editor.buffer_selector.getFileBuffer().openFile("src/e2e/mixed-byte-lines.txt");

        // Move to back half of double byte character
        for (0..5) |_| try editor.controller.processKeypress(.{ .arrow = .right });
        try std.testing.expectEqual(models.Position{ .x = 5, .y = 0 }, cursor.getPosition());
        try editor.controller.processKeypress(.{ .arrow = .down });
        try std.testing.expectFmt("(2, 1)", "{}", .{cursor.getPosition()});
        try std.testing.expectEqual(models.Position{ .x = 2, .y = 1 }, cursor.getPosition());
        try editor.controller.processKeypress(.{ .arrow = .up });
        try std.testing.expectEqual(models.Position{ .x = 5, .y = 0 }, cursor.getPosition());
    }
}
