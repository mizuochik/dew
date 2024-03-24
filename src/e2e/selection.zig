const std = @import("std");
const Editor = @import("../Editor.zig");
const Position = @import("../Position.zig");

test "move selection to any directions" {
    const editor = try Editor.init(std.testing.allocator, .{});
    defer editor.deinit();
    try editor.display.setSize(100, 100);
    const selection = &editor.client.getActiveFile().?.selection;
    try editor.client.getActiveFile().?.selection.text.openFile("src/e2e/100x100.txt");

    try editor.display.render();
    try std.testing.expectEqualDeep(Position{ .character = 0, .line = 0 }, selection.getPosition());

    for (0..5) |_| try editor.key_evaluator.evaluate(.{ .arrow = .right });
    try editor.display.render();
    try std.testing.expectEqualDeep(Position{ .character = 5, .line = 0 }, selection.getPosition());

    for (0..5) |_| try editor.key_evaluator.evaluate(.{ .arrow = .down });
    try editor.display.render();
    try std.testing.expectEqualDeep(Position{ .character = 5, .line = 5 }, selection.getPosition());

    for (0..4) |_| try editor.key_evaluator.evaluate(.{ .arrow = .left });
    try editor.display.render();
    try std.testing.expectEqualDeep(Position{ .character = 1, .line = 5 }, selection.getPosition());

    for (0..4) |_| try editor.key_evaluator.evaluate(.{ .arrow = .up });
    try editor.display.render();
    try std.testing.expectEqualDeep(Position{ .character = 1, .line = 1 }, selection.getPosition());
}

test "move to the beginning or end of line" {
    const editor = try Editor.init(std.testing.allocator, .{});
    defer editor.deinit();
    try editor.display.setSize(100, 100);
    const selection = &editor.client.getActiveFile().?.selection;
    try editor.client.getActiveFile().?.selection.text.openFile("src/e2e/100x100.txt");

    for (0..10) |_| try selection.moveForward();
    try editor.display.render();
    try std.testing.expectEqualDeep(Position{ .character = 10, .line = 0 }, selection.getPosition());
    try editor.key_evaluator.evaluate(.{ .ctrl = 'A' });
    try editor.display.render();
    try std.testing.expectEqualDeep(Position{ .character = 0, .line = 0 }, selection.getPosition());

    for (0..10) |_| try selection.moveForward();
    try editor.display.render();
    try std.testing.expectEqualDeep(Position{ .character = 10, .line = 0 }, selection.getPosition());
    try editor.key_evaluator.evaluate(.{ .ctrl = 'E' });
    try editor.display.render();
    try std.testing.expectEqualDeep(Position{ .character = 100, .line = 0 }, selection.getPosition());
}

test "move vertically considering double bytes" {
    {
        const editor = try Editor.init(std.testing.allocator, .{});
        defer editor.deinit();
        try editor.display.setSize(100, 100);
        const selection = &editor.client.getActiveFile().?.selection;
        try editor.client.getActiveFile().?.selection.text.openFile("src/e2e/mixed-byte-lines.txt");
        try editor.display.render();

        // Move to first half of double byte character
        for (0..4) |_| try editor.key_evaluator.evaluate(.{ .arrow = .right });
        try editor.display.render();
        try std.testing.expectEqual(Position{ .character = 4, .line = 0 }, selection.getPosition());
        try editor.key_evaluator.evaluate(.{ .arrow = .down });
        try editor.display.render();
        try std.testing.expectEqual(Position{ .character = 2, .line = 1 }, selection.getPosition());
        try editor.key_evaluator.evaluate(.{ .arrow = .up });
        try editor.display.render();
        try std.testing.expectEqual(Position{ .character = 4, .line = 0 }, selection.getPosition());
    }
    {
        const editor = try Editor.init(std.testing.allocator, .{});
        defer editor.deinit();
        try editor.display.setSize(100, 100);
        const selection = &editor.client.getActiveFile().?.selection;
        try editor.client.getActiveFile().?.selection.text.openFile("src/e2e/mixed-byte-lines.txt");
        try editor.display.render();

        // Move to back half of double byte character
        for (0..5) |_| try editor.key_evaluator.evaluate(.{ .arrow = .right });
        try editor.display.render();
        try std.testing.expectEqual(Position{ .character = 5, .line = 0 }, selection.getPosition());
        try editor.key_evaluator.evaluate(.{ .arrow = .down });
        try editor.display.render();
        try std.testing.expectFmt("2:3", "{}", .{selection.getPosition()});
        try std.testing.expectEqual(Position{ .character = 2, .line = 1 }, selection.getPosition());
        try editor.key_evaluator.evaluate(.{ .arrow = .up });
        try editor.display.render();
        try std.testing.expectEqual(Position{ .character = 5, .line = 0 }, selection.getPosition());
    }
}
