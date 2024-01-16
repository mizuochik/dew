const std = @import("std");
const Editor = @import("../Editor.zig");

test "input characters" {
    var editor = try Editor.init(std.testing.allocator, .{});
    defer editor.deinit();
    try editor.controller.changeDisplaySize(10, 10);

    try editor.controller.processKeypress(.{ .plain = 'a' });
    try editor.controller.processKeypress(.{ .plain = 'b' });
    try editor.controller.processKeypress(.{ .plain = 'c' });

    try editor.display.render();

    const area = try editor.display.getArea(0, 1, 0, 10);
    defer area.deinit();
    try area.expectEqualSlice(
        \\abc
    );
}

test "insert characters" {
    var editor = try Editor.init(std.testing.allocator, .{});
    defer editor.deinit();
    try editor.controller.changeDisplaySize(20, 20);
    try editor.controller.openFile("src/e2e/hello-world.txt");

    for (0..5) |_| {
        try editor.controller.processKeypress(.{ .arrow = .right });
    }
    for (" Bye") |c| {
        try editor.controller.processKeypress(.{ .plain = c });
    }

    try editor.display.render();
    const area = try editor.display.getArea(0, 1, 0, 20);
    defer area.deinit();
    try area.expectEqualSlice(
        \\Hello Bye World
    );
}

test "delete characters" {
    var editor = try Editor.init(std.testing.allocator, .{});
    defer editor.deinit();
    try editor.controller.changeDisplaySize(20, 20);
    try editor.controller.openFile("src/e2e/hello-world.txt");

    for (0..5) |_| {
        try editor.controller.processKeypress(.{ .arrow = .right });
    }
    for (0..5) |_| {
        try editor.controller.processKeypress(.{ .ctrl = 'D' });
    }

    try editor.display.render();
    const area = try editor.display.getArea(0, 1, 0, 20);
    defer area.deinit();
    try area.expectEqualSlice(
        \\Hellod
    );
}

test "delete backward characters" {
    var editor = try Editor.init(std.testing.allocator, .{});
    defer editor.deinit();
    try editor.controller.changeDisplaySize(20, 20);
    try editor.controller.openFile("src/e2e/hello-world.txt");

    for (0..10) |_| {
        try editor.controller.processKeypress(.{ .arrow = .right });
    }
    for (0..5) |_| {
        try editor.controller.processKeypress(.{ .ctrl = 'H' });
    }

    try editor.display.render();
    const area = try editor.display.getArea(0, 1, 0, 20);
    defer area.deinit();
    try area.expectEqualSlice(
        \\Hellod
    );
}

test "break lines" {
    var editor = try Editor.init(std.testing.allocator, .{});
    defer editor.deinit();
    try editor.controller.changeDisplaySize(20, 20);
    try editor.controller.openFile("src/e2e/hello-world.txt");

    for (0..5) |_| {
        try editor.controller.processKeypress(.{ .arrow = .right });
    }
    try editor.controller.processKeypress(.{ .ctrl = 'M' });

    try editor.display.render();
    const area = try editor.display.getArea(0, 2, 0, 20);
    defer area.deinit();
    try area.expectEqualSlice(
        \\Hello
        \\ World
    );
}

test "join lines" {
    var editor = try Editor.init(std.testing.allocator, .{});
    defer editor.deinit();
    try editor.controller.changeDisplaySize(20, 20);
    try editor.controller.openFile("src/e2e/hello-world-folded.txt");

    for (0..5) |_| {
        try editor.controller.processKeypress(.{ .arrow = .right });
    }
    try editor.controller.processKeypress(.{ .ctrl = 'J' });

    try editor.display.render();
    const area = try editor.display.getArea(0, 1, 0, 20);
    defer area.deinit();
    try area.expectEqualSlice(
        \\HelloWorld
    );
}

test "kill lines" {
    var editor = try Editor.init(std.testing.allocator, .{});
    defer editor.deinit();
    try editor.controller.changeDisplaySize(20, 20);
    try editor.controller.openFile("src/e2e/hello-world-folded.txt");

    try editor.controller.processKeypress(.{ .arrow = .right });
    try editor.controller.processKeypress(.{ .ctrl = 'K' });
    {
        try editor.display.render();
        const area = try editor.display.getArea(0, 2, 0, 20);
        defer area.deinit();
        try area.expectEqualSlice(
            \\H
            \\World
        );
    }

    try editor.controller.processKeypress(.{ .ctrl = 'K' });
    {
        try editor.display.render();
        const area = try editor.display.getArea(0, 2, 0, 20);
        defer area.deinit();
        try area.expectEqualSlice(
            \\HWorld
            \\
        );
    }
}
