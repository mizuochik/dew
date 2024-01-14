const std = @import("std");
const Editor = @import("../Editor.zig");

test "scroll down/up" {
    const editor = try Editor.init(std.testing.allocator, .{});
    defer editor.deinit();
    try editor.controller.changeDisplaySize(10, 11); // 11 lines = 10 lines (file content) + one line (status bar)
    try editor.client.getActiveFile().?.cursor.text.openFile("src/e2e/line-numbers.txt");
    try editor.display.render();

    try editor.controller.processKeypress(.{ .ctrl = 'V' });
    try editor.display.render();
    try std.testing.expectEqualStrings("11", editor.display.buffer[0][0..2]);
    try std.testing.expectEqualStrings("20", editor.display.buffer[9][0..2]);

    try editor.controller.processKeypress(.{ .ctrl = 'V' });
    try editor.display.render();
    try std.testing.expectEqualStrings("21", editor.display.buffer[0][0..2]);
    try std.testing.expectEqualStrings("30", editor.display.buffer[9][0..2]);

    try editor.controller.processKeypress(.{ .meta = 'v' });
    try editor.display.render();
    try std.testing.expectEqualStrings("11", editor.display.buffer[0][0..2]);
    try std.testing.expectEqualStrings("20", editor.display.buffer[9][0..2]);

    try editor.controller.processKeypress(.{ .meta = 'v' });
    try editor.display.render();
    try std.testing.expectEqualStrings("1 ", editor.display.buffer[0][0..2]);
    try std.testing.expectEqualStrings("10", editor.display.buffer[9][0..2]);
}
