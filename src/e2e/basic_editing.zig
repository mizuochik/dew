const std = @import("std");
const Editor = @import("../Editor.zig");
const models = @import("../models.zig");

test "input characters" {
    var editor = try Editor.init(std.testing.allocator);
    defer editor.deinit();
    try editor.controller.changeDisplaySize(10, 10);

    try editor.controller.processKeypress(.{ .plain = 'a' });
    try editor.controller.processKeypress(.{ .plain = 'b' });
    try editor.controller.processKeypress(.{ .plain = 'c' });

    const area = try editor.display.getArea(0, 1, 0, 10);
    defer area.deinit();

    try std.testing.expectEqualStrings("abc       ", area.rows[0]);
}
