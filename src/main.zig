const std = @import("std");
const dew = @import("dew.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .verbose_log = false,
    }){};
    defer std.debug.assert(gpa.deinit() == .ok);

    if (std.os.argv.len < 2) {
        try std.io.getStdErr().writer().print("Specify file\n", .{});
        std.os.exit(1);
    }
    const path: []const u8 = std.mem.span(std.os.argv[1]);

    var editor = try dew.Editor.init(gpa.allocator());
    defer editor.deinit();

    try editor.terminal.enableRawMode();
    defer editor.terminal.disableRawMode() catch unreachable;

    const win_size = try editor.terminal.getWindowSize();
    try editor.controller.changeDisplaySize(win_size.cols, win_size.rows);
    try editor.controller.openFile(path);

    {
        const msg = try std.fmt.allocPrint(gpa.allocator(), "Initialized", .{});
        errdefer gpa.allocator().free(msg);
        try editor.status_message.setMessage(msg);
    }

    while (true) {
        const key = try editor.keyboard.inputKey();
        editor.controller.processKeypress(key) catch |err| switch (err) {
            error.Quit => return,
            else => return err,
        };
    }
}

test {
    _ = dew;
}
