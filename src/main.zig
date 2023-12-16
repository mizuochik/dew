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

    var model_event_publisher = dew.event.Publisher(dew.models.Event).init(gpa.allocator());
    defer model_event_publisher.deinit();
    var view_event_publisher = dew.event.Publisher(dew.view.Event).init(gpa.allocator());
    defer view_event_publisher.deinit();

    var buffer = try dew.models.Buffer.init(gpa.allocator(), &model_event_publisher, .file);
    defer buffer.deinit();
    try buffer.addCursor();
    var buffer_view = dew.view.BufferView.init(gpa.allocator(), &buffer, &view_event_publisher);
    defer buffer_view.deinit();
    try model_event_publisher.addSubscriber(buffer_view.eventSubscriber());

    var command_buffer = try dew.models.Buffer.init(gpa.allocator(), &model_event_publisher, .command);
    defer command_buffer.deinit();
    try command_buffer.addCursor();
    var command_buffer_view = dew.view.BufferView.init(gpa.allocator(), &command_buffer, &view_event_publisher);
    defer command_buffer_view.deinit();
    try model_event_publisher.addSubscriber(command_buffer_view.eventSubscriber());

    var buffer_selector = dew.models.BufferSelector.init(&buffer, &command_buffer, &model_event_publisher);
    defer buffer_selector.deinit();

    var debug_handler = dew.models.debug.Handler{
        .buffer_selector = &buffer_selector,
        .allocator = gpa.allocator(),
    };
    try model_event_publisher.addSubscriber(debug_handler.eventSubscriber());

    var status_message = try dew.models.StatusMessage.init(gpa.allocator(), &model_event_publisher);
    defer status_message.deinit();
    var status_var_view = dew.view.StatusBarView.init(&status_message, &view_event_publisher);
    defer status_var_view.deinit();
    try model_event_publisher.addSubscriber(status_var_view.eventSubscriber());
    var display_size = dew.models.DisplaySize.init(&model_event_publisher);

    var editor_controller = try dew.controllers.EditorController.init(
        gpa.allocator(),
        &buffer_view,
        &command_buffer_view,
        &status_message,
        &buffer_selector,
        &display_size,
    );
    defer editor_controller.deinit();

    var editor = dew.Editor.init(gpa.allocator(), &editor_controller);

    const win_size = try editor.terminal.getWindowSize();
    var display = try dew.Display.init(gpa.allocator(), &buffer_view, &status_var_view, &command_buffer_view, win_size);
    defer display.deinit();
    try view_event_publisher.addSubscriber(display.eventSubscriber());

    var command_executor = dew.models.CommandExecutor{
        .buffer_selector = &buffer_selector,
        .status_message = &status_message,
        .allocator = gpa.allocator(),
    };
    try model_event_publisher.addSubscriber(command_executor.eventSubscriber());

    try editor.terminal.enableRawMode();
    defer editor.terminal.disableRawMode() catch unreachable;
    try editor.controller.openFile(path);

    try editor.controller.changeDisplaySize(win_size.cols, win_size.rows);

    {
        const msg = try std.fmt.allocPrint(gpa.allocator(), "Initialized", .{});
        errdefer gpa.allocator().free(msg);
        try status_message.setMessage(msg);
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
