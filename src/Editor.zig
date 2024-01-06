const std = @import("std");
const event = @import("event.zig");
const models = @import("models.zig");
const view = @import("view.zig");
const debug = @import("debug.zig");
const Keyboard = @import("Keyboard.zig");
const Terminal = @import("Terminal.zig");
const Display = @import("Display.zig");
const CommandEvaluator = @import("CommandEvaluator.zig");
const BufferSelector = @import("BufferSelector.zig");
const StatusMessage = @import("StatusMessage.zig");
const BufferView = @import("BufferView.zig");
const StatusBarView = @import("StatusBarView.zig");
const DisplaySize = @import("DisplaySize.zig");
const EditorController = @import("EditorController.zig");

const Editor = @This();

pub const Options = struct {
    is_debug: bool = false,
};

allocator: std.mem.Allocator,
model_event_publisher: *event.Publisher(models.Event),
view_event_publisher: *event.Publisher(view.Event),
buffer_view: *BufferView,
command_buffer_view: *BufferView,
buffer_selector: *BufferSelector,
debug_handler: ?*debug.Handler,
status_message: *StatusMessage,
status_bar_view: *StatusBarView,
display_size: *DisplaySize,
controller: *EditorController,
command_evaluator: *CommandEvaluator,
keyboard: *Keyboard,
terminal: *Terminal,
display: *Display,

pub fn init(allocator: std.mem.Allocator, options: Options) !*Editor {
    const editor = try allocator.create(Editor);
    errdefer allocator.destroy(editor);

    const model_event_publisher = try allocator.create(event.Publisher(models.Event));
    errdefer allocator.destroy(model_event_publisher);
    model_event_publisher.* = event.Publisher(models.Event).init(allocator);
    errdefer model_event_publisher.deinit();

    const view_event_publisher = try allocator.create(event.Publisher(view.Event));
    errdefer allocator.destroy(view_event_publisher);
    view_event_publisher.* = event.Publisher(view.Event).init(allocator);
    errdefer view_event_publisher.deinit();

    const buffer_selector = try allocator.create(BufferSelector);
    errdefer allocator.destroy(buffer_selector);
    buffer_selector.* = try BufferSelector.init(allocator, model_event_publisher);
    errdefer buffer_selector.deinit();

    const buffer_view = try allocator.create(BufferView);
    errdefer allocator.destroy(buffer_view);
    buffer_view.* = BufferView.init(allocator, buffer_selector, .file, view_event_publisher);
    errdefer buffer_view.deinit();
    try model_event_publisher.addSubscriber(buffer_view.eventSubscriber());

    const command_buffer_view = try allocator.create(BufferView);
    errdefer allocator.destroy(command_buffer_view);
    command_buffer_view.* = BufferView.init(allocator, buffer_selector, .command, view_event_publisher);
    errdefer command_buffer_view.deinit();
    try model_event_publisher.addSubscriber(command_buffer_view.eventSubscriber());

    const debug_handler: ?*debug.Handler = if (options.is_debug) b: {
        const debug_handler = try allocator.create(debug.Handler);
        errdefer allocator.destroy(debug_handler);
        debug_handler.* = debug.Handler{
            .buffer_selector = buffer_selector,
            .allocator = allocator,
        };
        try model_event_publisher.addSubscriber(debug_handler.eventSubscriber());
        break :b debug_handler;
    } else null;
    errdefer if (debug_handler) |handler| allocator.destroy(handler);

    const status_message = try allocator.create(StatusMessage);
    errdefer allocator.destroy(status_message);
    status_message.* = try StatusMessage.init(allocator, model_event_publisher);
    errdefer status_message.deinit();

    const status_bar_view = try allocator.create(StatusBarView);
    errdefer allocator.destroy(status_bar_view);
    status_bar_view.* = StatusBarView.init(status_message, view_event_publisher);
    errdefer status_bar_view.deinit();
    try model_event_publisher.addSubscriber(status_bar_view.eventSubscriber());

    const display_size = try allocator.create(DisplaySize);
    errdefer allocator.destroy(display_size);
    display_size.* = DisplaySize.init(view_event_publisher);

    const editor_controller = try allocator.create(EditorController);
    errdefer allocator.destroy(editor_controller);
    editor_controller.* = try EditorController.init(
        allocator,
        buffer_view,
        command_buffer_view,
        status_message,
        buffer_selector,
        display_size,
    );
    errdefer editor_controller.deinit();

    const command_evaluator = try allocator.create(CommandEvaluator);
    errdefer allocator.destroy(command_evaluator);
    command_evaluator.* = CommandEvaluator{
        .editor = editor,
        .buffer_selector = buffer_selector,
        .status_message = status_message,
        .allocator = allocator,
    };
    try model_event_publisher.addSubscriber(command_evaluator.eventSubscriber());

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

    editor.* = Editor{
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
        .command_evaluator = command_evaluator,
        .keyboard = keyboard,
        .terminal = terminal,
        .display = display,
    };
    return editor;
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

    self.allocator.destroy(self.command_evaluator);

    if (self.debug_handler) |handler| {
        self.allocator.destroy(handler);
    }

    self.controller.deinit();
    self.allocator.destroy(self.controller);

    self.allocator.destroy(self.display_size);
    self.allocator.destroy(self.keyboard);
    self.allocator.destroy(self.terminal);

    self.view_event_publisher.deinit();
    self.allocator.destroy(self.view_event_publisher);

    self.model_event_publisher.deinit();
    self.allocator.destroy(self.model_event_publisher);

    self.allocator.destroy(self);
}
