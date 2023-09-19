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
        .verbose_log = false,
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

    var buffer = try models.Buffer.init(gpa.allocator(), &model_event_publisher, .file);
    defer buffer.deinit();
    var buffer_view = view.BufferView.init(gpa.allocator(), &buffer, &view_event_publisher);
    defer buffer_view.deinit();
    try buffer.addObserver(buffer_view.bufferObserver());
    try model_event_publisher.addSubscriber(buffer_view.eventSubscriber());

    var command_buffer = try models.Buffer.init(gpa.allocator(), &model_event_publisher, .command);
    defer command_buffer.deinit();
    var command_buffer_view = view.BufferView.init(gpa.allocator(), &command_buffer, &view_event_publisher);
    defer command_buffer_view.deinit();
    try command_buffer.addObserver(command_buffer_view.bufferObserver());
    try model_event_publisher.addSubscriber(command_buffer_view.eventSubscriber());

    var buffer_selector = models.BufferSelector.init(&buffer, &command_buffer, &model_event_publisher);
    defer buffer_selector.deinit();

    var status_message = try models.StatusMessage.init(gpa.allocator(), &model_event_publisher);
    defer status_message.deinit();
    var status_var_view = view.StatusBarView.init(&status_message, &view_event_publisher);
    defer status_var_view.deinit();
    try model_event_publisher.addSubscriber(status_var_view.eventSubscriber());

    var buffer_controller = try dew.controllers.EditorController.init(
        gpa.allocator(),
        &buffer_view,
        &status_message,
        &buffer_selector,
        &model_event_publisher,
    );
    defer buffer_controller.deinit();

    var editor = dew.Editor.init(gpa.allocator(), &buffer_controller);

    const win_size = try editor.getWindowSize();
    var display = dew.Display{
        .buffer_view = &buffer_view,
        .status_bar_view = &status_var_view,
        .command_buffer_view = &command_buffer_view,
        .allocator = gpa.allocator(),
        .size = win_size,
    };
    try view_event_publisher.addSubscriber(display.eventSubscriber());

    try editor.enableRawMode();
    defer editor.disableRawMode() catch unreachable;
    try editor.buffer_controller.openFile(path);

    try model_event_publisher.publish(.{
        .screen_size_changed = .{
            .width = win_size.cols,
            .height = win_size.rows,
        },
    });

    const msg = try fmt.allocPrint(gpa.allocator(), "Initialized", .{});
    errdefer gpa.allocator().free(msg);
    try status_message.setMessage(msg);

    try editor.run();
}
