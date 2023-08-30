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
const EditorController = dew.controllers.EditorController;
const models = dew.models;
const view = dew.view;
const Publisher = dew.event.Publisher;
const Subscriber = dew.event.Subscriber;

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

    var model_event_publisher = dew.event.Publisher(dew.models.Event).init(gpa.allocator());
    defer model_event_publisher.deinit();
    var view_event_publisher = dew.event.Publisher(dew.view.Event).init(gpa.allocator());
    defer view_event_publisher.deinit();

    var buffer = models.Buffer.init(gpa.allocator(), &model_event_publisher);
    defer buffer.deinit();
    var buffer_view = view.BufferView.init(gpa.allocator(), &buffer, &view_event_publisher);
    defer buffer_view.deinit();
    var status_message = try models.StatusMessage.init(gpa.allocator(), &model_event_publisher);
    defer status_message.deinit();
    var display = dew.Display{
        .buffer_view = &buffer_view,
        .allocator = gpa.allocator(),
    };
    var buffer_controller = try dew.controllers.EditorController.init(
        gpa.allocator(),
        &buffer,
        &buffer_view,
        &status_message,
        &model_event_publisher,
    );
    defer buffer_controller.deinit();
    var editor = dew.Editor.init(gpa.allocator(), &buffer_controller);

    try model_event_publisher.addSubscriber(buffer_view.eventSubscriber());
    try view_event_publisher.addSubscriber(display.eventSubscriber());

    try editor.enableRawMode();
    defer editor.disableRawMode() catch unreachable;
    try editor.buffer_controller.openFile(path);

    const win_size = try editor.getWindowSize();
    try model_event_publisher.publish(.{
        .screen_size_changed = .{
            .width = win_size.cols,
            .height = win_size.rows,
        },
    });

    try editor.run();
}
