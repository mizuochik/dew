const std = @import("std");
const heap = std.heap;
const os = std.os;
const fmt = std.fmt;
const io = std.io;
const time = std.time;
const debug = std.debug;
const mem = std.mem;
const log = std.log;
const fs = std.fs;
const dew = @import("dew.zig");

var log_file: ?fs.File = null;
const log_file_name = "dew.log";

fn writeLog(comptime message_level: log.Level, comptime scope: @TypeOf(.enum_literal), comptime format: []const u8, args: anytype) void {
    _ = scope;
    _ = message_level;
    const f = log_file orelse return;
    f.writer().print(format ++ "\n", args) catch return;
}

pub const std_options = struct {
    pub const log_level = .info;
    pub const logFn = writeLog;
};

pub fn main() !void {
    log_file = try fs.cwd().createFile(log_file_name, .{ .truncate = false });
    defer if (log_file) |f| f.close();
    const stat = try log_file.?.stat();
    try log_file.?.seekTo(stat.size);

    var gpa = heap.GeneralPurposeAllocator(.{
        .verbose_log = true,
    }){};
    defer debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    if (os.argv.len < 2) {
        try io.getStdErr().writer().print("Specify file\n", .{});
        os.exit(1);
    }
    const path: []const u8 = mem.span(os.argv[1]);

    var editor = try dew.Editor.init(allocator);
    defer editor.deinit() catch unreachable;

    try editor.buffer_controller.openFile(path);
    try editor.run();
}
