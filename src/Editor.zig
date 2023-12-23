const std = @import("std");
const event = @import("event.zig");
const models = @import("models.zig");
const view = @import("view.zig");
const controllers = @import("controllers.zig");
const Keyboard = @import("Keyboard.zig");
const Terminal = @import("Terminal.zig");
const Display = @import("Display.zig");

const Editor = @This();

allocator: std.mem.Allocator,
model_event_publisher: *event.Publisher(models.Event),
view_event_publisher: *event.Publisher(view.Event),
buffer_view: *view.BufferView,
command_buffer_view: *view.BufferView,
buffer_selector: *models.BufferSelector,
debug_handler: *models.debug.Handler,
status_message: *models.StatusMessage,
status_bar_view: *view.StatusBarView,
display_size: *view.DisplaySize,
controller: *controllers.EditorController,
command_executor: *models.CommandExecutor,
keyboard: *Keyboard,
terminal: *Terminal,
display: *Display,

pub fn init(allocator: std.mem.Allocator) !Editor {
    const model_event_publisher = try allocator.create(event.Publisher(models.Event));
    errdefer allocator.destroy(model_event_publisher);
    model_event_publisher.* = event.Publisher(models.Event).init(allocator);
    errdefer model_event_publisher.deinit();

    const view_event_publisher = try allocator.create(event.Publisher(view.Event));
    errdefer allocator.destroy(view_event_publisher);
    view_event_publisher.* = event.Publisher(view.Event).init(allocator);
    errdefer view_event_publisher.deinit();

    const buffer_selector = try allocator.create(models.BufferSelector);
    errdefer allocator.destroy(buffer_selector);
    buffer_selector.* = try models.BufferSelector.init(allocator, model_event_publisher);
    errdefer buffer_selector.deinit();

    const buffer_view = try allocator.create(view.BufferView);
    errdefer allocator.destroy(buffer_view);
    buffer_view.* = view.BufferView.init(allocator, buffer_selector, .file, view_event_publisher);
    errdefer buffer_view.deinit();
    try model_event_publisher.addSubscriber(buffer_view.eventSubscriber());

    const command_buffer_view = try allocator.create(view.BufferView);
    errdefer allocator.destroy(command_buffer_view);
    command_buffer_view.* = view.BufferView.init(allocator, buffer_selector, .command, view_event_publisher);
    errdefer command_buffer_view.deinit();
    try model_event_publisher.addSubscriber(command_buffer_view.eventSubscriber());

    const debug_handler = try allocator.create(models.debug.Handler);
    errdefer allocator.destroy(debug_handler);
    debug_handler.* = models.debug.Handler{
        .buffer_selector = buffer_selector,
        .allocator = allocator,
    };
    try model_event_publisher.addSubscriber(debug_handler.eventSubscriber());

    const status_message = try allocator.create(models.StatusMessage);
    errdefer allocator.destroy(status_message);
    status_message.* = try models.StatusMessage.init(allocator, model_event_publisher);
    errdefer status_message.deinit();

    const status_bar_view = try allocator.create(view.StatusBarView);
    errdefer allocator.destroy(status_bar_view);
    status_bar_view.* = view.StatusBarView.init(status_message, view_event_publisher);
    errdefer status_bar_view.deinit();
    try model_event_publisher.addSubscriber(status_bar_view.eventSubscriber());

    const display_size = try allocator.create(view.DisplaySize);
    errdefer allocator.destroy(display_size);
    display_size.* = view.DisplaySize.init(view_event_publisher);

    const editor_controller = try allocator.create(controllers.EditorController);
    errdefer allocator.destroy(editor_controller);
    editor_controller.* = try controllers.EditorController.init(
        allocator,
        buffer_view,
        command_buffer_view,
        status_message,
        buffer_selector,
        display_size,
    );
    errdefer editor_controller.deinit();

    const command_executor = try allocator.create(models.CommandExecutor);
    errdefer allocator.destroy(command_executor);
    command_executor.* = models.CommandExecutor{
        .buffer_selector = buffer_selector,
        .status_message = status_message,
        .allocator = allocator,
    };
    try model_event_publisher.addSubscriber(command_executor.eventSubscriber());

    const keyboard = try allocator.create(Keyboard);
    errdefer allocator.destroy(keyboard);
    keyboard.* = Keyboard{};

    const terminal = try allocator.create(Terminal);
    errdefer allocator.destroy(terminal);
    terminal.* = .{};

    const display = try allocator.create(Display);
    errdefer allocator.destroy(display);
    display.* = try Display.init(allocator, buffer_view, status_bar_view, command_buffer_view, display_size);
    errdefer display.deinit();
    try view_event_publisher.addSubscriber(display.eventSubscriber());

    return Editor{
        .allocator = allocator,
        .model_event_publisher = model_event_publisher,
        .view_event_publisher = view_event_publisher,
        .buffer_view = buffer_view,
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
    self.buffer_view.deinit();
    self.allocator.destroy(self.buffer_view);

    self.command_buffer_view.deinit();
    self.allocator.destroy(self.command_buffer_view);

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
