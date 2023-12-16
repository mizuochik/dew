const std = @import("std");
const dew = @import("dew.zig");

var log_file: ?std.fs.File = null;
const log_file_name = "dew.log";

fn writeLog(comptime message_level: std.log.Level, comptime scope: @TypeOf(.enum_literal), comptime format: []const u8, args: anytype) void {
    _ = scope;
    _ = message_level;
    const f = log_file orelse return;
    f.writer().print(format ++ "\n", args) catch return;
}

pub const std_options = struct {
    pub const log_level = .debug;
    pub const logFn = writeLog;
};

pub fn main() !void {
    log_file = try std.fs.cwd().createFile(log_file_name, .{ .truncate = false });
    defer if (log_file) |f| f.close();
    const stat = try log_file.?.stat();
    try log_file.?.seekTo(stat.size);

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

    const win_size = try editor.terminal.getWindowSize();

    try editor.terminal.enableRawMode();
    defer editor.terminal.disableRawMode() catch unreachable;
    try editor.controller.openFile(path);

    try editor.controller.changeDisplaySize(win_size.cols, win_size.rows);

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
