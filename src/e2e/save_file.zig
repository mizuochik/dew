const std = @import("std");
const Editor = @import("../Editor.zig");

test "save existing buffer" {
    var editor = try Editor.init(std.testing.allocator, .{});
    defer editor.deinit();
    try editor.controller.changeDisplaySize(10, 10);
    const area = try editor.display.getArea(0, 10, 0, 10);
    defer area.deinit();
    try std.fs.cwd().copyFile("src/e2e/hello-world.txt", std.fs.cwd(), "src/e2e/hello-world.tmp.txt", .{});
    defer std.fs.cwd().deleteFile("src/e2e/hello-world.tmp.txt") catch {};
    try editor.controller.processKeypress(.{ .ctrl = 'X' });
    for ("open-file src/e2e/hello-world.tmp.txt") |c| {
        try editor.controller.processKeypress(.{ .plain = c });
    }
    try editor.controller.processKeypress(.{ .ctrl = 'M' });

    for ("Hello World ") |c| {
        try editor.controller.processKeypress(.{ .plain = c });
    }
    try editor.controller.processKeypress(.{ .ctrl = 'S' });

    var buf: [100]u8 = undefined;
    const actual = try std.fs.cwd().readFile("src/e2e/hello-world.tmp.txt", &buf);
    try std.testing.expectEqualStrings("Hello World Hello World\n", actual);
}
