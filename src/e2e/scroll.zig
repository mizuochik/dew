const std = @import("std");
const Editor = @import("../Editor.zig");

test "scroll down/up" {
    const editor = try Editor.init(std.testing.allocator, .{});
    defer editor.deinit();
    try editor.display.setSize(10, 11); // 11 lines = 10 lines (file content) + one line (status bar)
    try editor.client.getActiveFile().?.selection.text.openFile("src/e2e/line-numbers.txt");
    try editor.display.render();
    {
        try editor.key_evaluator.evaluate(.{ .ctrl = 'V' });
        try editor.display.render();
        const area = try editor.display.getArea(0, 10, 0, 10);
        defer area.deinit();
        try area.expectEqualSlice(
            \\11
            \\12
            \\13
            \\14
            \\15
            \\16
            \\17
            \\18
            \\19
            \\20
        );
    }
    {
        try editor.key_evaluator.evaluate(.{ .ctrl = 'V' });
        try editor.display.render();
        const area = try editor.display.getArea(0, 10, 0, 10);
        defer area.deinit();
        try area.expectEqualSlice(
            \\21
            \\22
            \\23
            \\24
            \\25
            \\26
            \\27
            \\28
            \\29
            \\30
        );
    }
    {
        try editor.key_evaluator.evaluate(.{ .meta = 'v' });
        try editor.display.render();
        const area = try editor.display.getArea(0, 10, 0, 10);
        defer area.deinit();
        try area.expectEqualSlice(
            \\11
            \\12
            \\13
            \\14
            \\15
            \\16
            \\17
            \\18
            \\19
            \\20
        );
    }
    {
        try editor.key_evaluator.evaluate(.{ .meta = 'v' });
        try editor.display.render();
        const area = try editor.display.getArea(0, 10, 0, 10);
        defer area.deinit();
        try area.expectEqualSlice(
            \\1
            \\2
            \\3
            \\4
            \\5
            \\6
            \\7
            \\8
            \\9
            \\10
        );
    }
}
