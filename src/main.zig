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
const BufferController = dew.controllers.BufferController;
const models = dew.models;
const view = dew.view;
const EventPublisher = dew.event.EventPublisher;
const EventSubscriber = dew.event.EventSubscriber;

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

    if (os.argv.len < 2) {
        try io.getStdErr().writer().print("Specify file\n", .{});
        os.exit(1);
    }
    const path: []const u8 = mem.span(os.argv[1]);

    var buffer_controller = try dew.controllers.BufferController.init(gpa.allocator());
    defer buffer_controller.deinit();
    var model_event_publisher = dew.event.EventPublisher(dew.models.Event).init(gpa.allocator());
    defer model_event_publisher.deinit();
    var editor = try dew.Editor.init(gpa.allocator(), &buffer_controller);
    defer editor.deinit() catch unreachable;

    try editor.enableRawMode();
    defer editor.disableRawMode() catch unreachable;

    const win_size = try editor.getWindowSize();
    try model_event_publisher.publish(.{
        .screen_size_changed = .{
            .width = win_size.cols,
            .height = win_size.rows,
        },
    });

    try editor.buffer_controller.openFile(path);
    try editor.run();
}
