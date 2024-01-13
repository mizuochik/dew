const std = @import("std");
const models = @import("models.zig");
const view = @import("view.zig");
const Keyboard = @import("Keyboard.zig");
const Terminal = @import("Terminal.zig");
const Display = @import("Display.zig");
const CommandEvaluator = @import("CommandEvaluator.zig");
const BufferSelector = @import("BufferSelector.zig");
const Status = @import("Status.zig");
const Client = @import("Client.zig");
const EditView = @import("EditView.zig");
const StatusView = @import("StatusView.zig");
const DisplaySize = @import("DisplaySize.zig");
const CommandRegistry = @import("CommandRegistry.zig");
const EditorController = @import("EditorController.zig");

const Editor = @This();

pub const Options = struct {
    is_debug: bool = false,
};

allocator: std.mem.Allocator,
edit_view: EditView,
command_edit_view: EditView,
buffer_selector: BufferSelector,
status: Status,
status_view: StatusView,
display_size: DisplaySize,
controller: EditorController,
command_evaluator: CommandEvaluator,
command_registry: CommandRegistry,
keyboard: Keyboard,
terminal: Terminal,
client: Client,
display: Display,

pub fn init(allocator: std.mem.Allocator, _: Options) !*Editor {
    const editor = try allocator.create(Editor);
    errdefer allocator.destroy(editor);

    editor.allocator = allocator;

    var client = try Client.init(allocator);
    errdefer client.deinit();
    editor.client = client;

    editor.buffer_selector = try BufferSelector.init(allocator, editor);
    errdefer editor.buffer_selector.deinit();

    editor.edit_view = EditView.init(allocator, editor, .file);
    errdefer editor.edit_view.deinit();

    editor.command_edit_view = EditView.init(allocator, editor, .command);
    errdefer editor.command_edit_view.deinit();

    editor.status = try Status.init(allocator);
    errdefer editor.status.deinit();

    editor.status_view = StatusView.init(&editor.status);
    errdefer editor.status_view.deinit();

    editor.display_size = DisplaySize.init();
    editor.display = try Display.init(allocator, &editor.edit_view, &editor.status_view, &editor.command_edit_view, &editor.display_size);
    errdefer editor.display.deinit();

    editor.controller = try EditorController.init(
        allocator,
        &editor.edit_view,
        &editor.command_edit_view,
        &editor.status,
        &editor.buffer_selector,
        &editor.display,
        &editor.display_size,
        editor,
    );
    errdefer editor.controller.deinit();

    editor.command_evaluator = .{
        .editor = editor,
    };

    editor.command_registry = CommandRegistry.init(allocator);
    errdefer editor.command_registry.deinit();
    try editor.command_registry.registerBuiltinCommands();

    editor.keyboard = .{};
    editor.terminal = .{};

    return editor;
}

pub fn deinit(self: *Editor) void {
    self.edit_view.deinit();
    self.command_edit_view.deinit();
    self.buffer_selector.deinit();
    self.status.deinit();
    self.status_view.deinit();
    self.display.deinit();
    self.command_registry.deinit();
    self.controller.deinit();
    self.client.deinit();
    self.allocator.destroy(self);
}
