const std = @import("std");
const dew = @import("../dew.zig");

const Editor = @This();

allocator: std.mem.Allocator,
model_event_publisher: *dew.event.Publisher(dew.models.Event),
view_event_publisher: *dew.event.Publisher(dew.view.Event),
buffer: *dew.models.Buffer,
buffer_view: *dew.view.BufferView,
command_buffer: *dew.models.Buffer,
command_buffer_view: *dew.view.BufferView,
buffer_selector: *dew.models.BufferSelector,
debug_handler: *dew.models.debug.Handler,
status_message: *dew.models.StatusMessage,
status_bar_view: *dew.view.StatusBarView,
display_size: *dew.view.DisplaySize,
controller: *dew.controllers.EditorController,
command_executor: *dew.models.CommandExecutor,
keyboard: *dew.Keyboard,
terminal: *dew.Terminal,
display: *dew.Display,

pub fn init(allocator: std.mem.Allocator) !Editor {
    const model_event_publisher = try allocator.create(dew.event.Publisher(dew.models.Event));
    errdefer allocator.destroy(model_event_publisher);
    model_event_publisher.* = dew.event.Publisher(dew.models.Event).init(allocator);
    errdefer model_event_publisher.deinit();

    const view_event_publisher = try allocator.create(dew.event.Publisher(dew.view.Event));
    errdefer allocator.destroy(view_event_publisher);
    view_event_publisher.* = dew.event.Publisher(dew.view.Event).init(allocator);
    errdefer view_event_publisher.deinit();

    const buffer = try allocator.create(dew.models.Buffer);
    errdefer allocator.destroy(buffer);
    buffer.* = try dew.models.Buffer.init(allocator, model_event_publisher, .file);
    errdefer buffer.deinit();
    try buffer.addCursor();

    const buffer_view = try allocator.create(dew.view.BufferView);
    errdefer allocator.destroy(buffer_view);
    buffer_view.* = dew.view.BufferView.init(allocator, buffer, view_event_publisher);
    errdefer buffer_view.deinit();
    try model_event_publisher.addSubscriber(buffer_view.eventSubscriber());

    const command_buffer = try allocator.create(dew.models.Buffer);
    errdefer allocator.destroy(command_buffer);
    command_buffer.* = try dew.models.Buffer.init(allocator, model_event_publisher, .command);
    errdefer command_buffer.deinit();
    try command_buffer.addCursor();

    const command_buffer_view = try allocator.create(dew.view.BufferView);
    errdefer allocator.destroy(command_buffer_view);
    command_buffer_view.* = dew.view.BufferView.init(allocator, command_buffer, view_event_publisher);
    errdefer command_buffer_view.deinit();
    try model_event_publisher.addSubscriber(command_buffer_view.eventSubscriber());

    const buffer_selector = try allocator.create(dew.models.BufferSelector);
    errdefer allocator.destroy(buffer_selector);
    buffer_selector.* = dew.models.BufferSelector.init(buffer, command_buffer, model_event_publisher);
    errdefer buffer_selector.deinit();

    const debug_handler = try allocator.create(dew.models.debug.Handler);
    errdefer allocator.destroy(debug_handler);
    debug_handler.* = dew.models.debug.Handler{
        .buffer_selector = buffer_selector,
        .allocator = allocator,
    };
    try model_event_publisher.addSubscriber(debug_handler.eventSubscriber());

    const status_message = try allocator.create(dew.models.StatusMessage);
    errdefer allocator.destroy(status_message);
    status_message.* = try dew.models.StatusMessage.init(allocator, model_event_publisher);
    errdefer status_message.deinit();

    const status_bar_view = try allocator.create(dew.view.StatusBarView);
    errdefer allocator.destroy(status_bar_view);
    status_bar_view.* = dew.view.StatusBarView.init(status_message, view_event_publisher);
    errdefer status_bar_view.deinit();
    try model_event_publisher.addSubscriber(status_bar_view.eventSubscriber());

    const display_size = try allocator.create(dew.view.DisplaySize);
    errdefer allocator.destroy(display_size);
    display_size.* = dew.view.DisplaySize.init(view_event_publisher);

    const editor_controller = try allocator.create(dew.controllers.EditorController);
    errdefer allocator.destroy(editor_controller);
    editor_controller.* = try dew.controllers.EditorController.init(
        allocator,
        buffer_view,
        command_buffer_view,
        status_message,
        buffer_selector,
        display_size,
    );
    errdefer editor_controller.deinit();

    const command_executor = try allocator.create(dew.models.CommandExecutor);
    errdefer allocator.destroy(command_executor);
    command_executor.* = dew.models.CommandExecutor{
        .buffer_selector = buffer_selector,
        .status_message = status_message,
        .allocator = allocator,
    };
    try model_event_publisher.addSubscriber(command_executor.eventSubscriber());

    const keyboard = try allocator.create(dew.Keyboard);
    errdefer allocator.destroy(keyboard);
    keyboard.* = dew.Keyboard{};

    const terminal = try allocator.create(dew.Terminal);
    errdefer allocator.destroy(terminal);
    terminal.* = .{};

    const win_size = try terminal.getWindowSize();
    display_size.rows = win_size.rows;
    display_size.cols = win_size.cols;

    const display = try allocator.create(dew.Display);
    errdefer allocator.destroy(display);
    display.* = try dew.Display.init(allocator, buffer_view, status_bar_view, command_buffer_view, display_size);
    errdefer display.deinit();
    try view_event_publisher.addSubscriber(display.eventSubscriber());

    return Editor{
        .allocator = allocator,
        .model_event_publisher = model_event_publisher,
        .view_event_publisher = view_event_publisher,
        .buffer = buffer,
        .buffer_view = buffer_view,
        .command_buffer = command_buffer,
        .command_buffer_view = command_buffer_view,
        .buffer_selector = buffer_selector,
        .debug_handler = debug_handler,
        .status_message = status_message,
        .status_bar_view = status_bar_view,
        .display_size = display_size,
        .controller = editor_controller,
        .command_executor = command_executor,
        .keyboard = keyboard,
        .terminal = terminal,
        .display = display,
    };
}

pub fn deinit(self: *const Editor) void {
    self.buffer.deinit();
    self.allocator.destroy(self.buffer);

    self.buffer_view.deinit();
    self.allocator.destroy(self.buffer_view);

    self.command_buffer_view.deinit();
    self.allocator.destroy(self.command_buffer_view);

    self.command_buffer.deinit();
    self.allocator.destroy(self.command_buffer);

    self.buffer_selector.deinit();
    self.allocator.destroy(self.buffer_selector);

    self.status_message.deinit();
    self.allocator.destroy(self.status_message);

    self.status_bar_view.deinit();
    self.allocator.destroy(self.status_bar_view);

    self.display.deinit();
    self.allocator.destroy(self.display);

    self.allocator.destroy(self.command_executor);

    self.allocator.destroy(self.debug_handler);

    self.controller.deinit();
    self.allocator.destroy(self.controller);

    self.allocator.destroy(self.display_size);
    self.allocator.destroy(self.keyboard);
    self.allocator.destroy(self.terminal);

    self.view_event_publisher.deinit();
    self.allocator.destroy(self.view_event_publisher);

    self.model_event_publisher.deinit();
    self.allocator.destroy(self.model_event_publisher);
}
