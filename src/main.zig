const std = @import("std");
const clap = @import("clap");
const Editor = @import("Editor.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .verbose_log = false,
    }){};
    defer std.debug.assert(gpa.deinit() == .ok);

    var diagnostic = clap.Diagnostic{};
    const params = comptime clap.parseParamsComptime(
        \\--debug Enable debug mode
        \\<str>
        \\
    );
    const res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .allocator = gpa.allocator(),
        .diagnostic = &diagnostic,
    }) catch |err| {
        try diagnostic.report(std.io.getStdErr().writer(), err);
        return;
    };
    defer res.deinit();

    var editor = try Editor.init(gpa.allocator(), .{
        .is_debug = res.args.debug > 0,
    });
    defer editor.deinit();

    try editor.terminal.enableRawMode();
    defer editor.terminal.disableRawMode() catch unreachable;

    const win_size = try editor.terminal.getWindowSize();
    try editor.controller.changeDisplaySize(win_size.cols, win_size.rows);
    try editor.controller.openFile(res.positionals[0]);
    {
        const msg = try std.fmt.allocPrint(gpa.allocator(), "Initialized", .{});
        errdefer gpa.allocator().free(msg);
        try editor.status_message.setMessage(msg);
    }
    try editor.display.render();

    while (true) {
        const key = try editor.keyboard.inputKey();
        editor.controller.processKeypress(key) catch |err| switch (err) {
            error.Quit => return,
            else => return err,
        };
        try editor.display.render();
    }
}

test {
    _ = @import("Editor.zig");
    _ = @import("Display.zig");
    _ = @import("Terminal.zig");
    _ = @import("event.zig");
    _ = @import("keyboard.zig");
    _ = @import("view.zig");
    _ = @import("models.zig");
    _ = @import("e2e.zig");
}
