const std = @import("std");
const Keyboard = @import("Keyboard.zig");
const Terminal = @import("Terminal.zig");
const Display = @import("Display.zig");
const MethodEvaluator = @import("MethodEvaluator.zig");
const BufferSelector = @import("BufferSelector.zig");
const Status = @import("Status.zig");
const Client = @import("Client.zig");
const EditView = @import("EditView.zig");
const StatusView = @import("StatusView.zig");
const DisplaySize = @import("DisplaySize.zig");
const ResourceRegistry = @import("ResourceRegistry.zig");
const EditorController = @import("EditorController.zig");

pub const Options = struct {
    is_debug: bool = false,
};

allocator: std.mem.Allocator,
edit_view: EditView,
command_edit_view: EditView,
buffer_selector: BufferSelector,
status_view: StatusView,
display_size: DisplaySize,
controller: EditorController,
method_evaluator: MethodEvaluator,
resource_registry: ResourceRegistry,
keyboard: Keyboard,
terminal: Terminal,
client: Client,
display: Display,

pub fn init(allocator: std.mem.Allocator, _: Options) !*@This() {
    const editor = try allocator.create(@This());
    errdefer allocator.destroy(editor);

    editor.allocator = allocator;

    editor.client = try Client.init(allocator);
    errdefer editor.client.deinit();

    editor.buffer_selector = try BufferSelector.init(allocator, editor);
    errdefer editor.buffer_selector.deinit();

    editor.edit_view = EditView.init(allocator, editor, .file);
    errdefer editor.edit_view.deinit();

    editor.command_edit_view = EditView.init(allocator, editor, .command);
    errdefer editor.command_edit_view.deinit();

    editor.status_view = StatusView.init();
    errdefer editor.status_view.deinit();

    editor.display_size = DisplaySize.init();
    editor.display = try Display.init(allocator, &editor.edit_view, &editor.status_view, &editor.command_edit_view, &editor.client, &editor.display_size);
    errdefer editor.display.deinit();

    editor.controller = try EditorController.init(
        allocator,
        &editor.edit_view,
        &editor.command_edit_view,
        &editor.buffer_selector,
        &editor.display,
        &editor.display_size,
        editor,
    );
    errdefer editor.controller.deinit();

    editor.method_evaluator = .{
        .editor = editor,
    };

    editor.resource_registry = ResourceRegistry.init(allocator);
    errdefer editor.resource_registry.deinit();
    try editor.resource_registry.registerBuiltinResources();

    editor.keyboard = .{};
    editor.terminal = .{};

    return editor;
}

pub fn deinit(self: *@This()) void {
    self.edit_view.deinit();
    self.command_edit_view.deinit();
    self.buffer_selector.deinit();
    self.status_view.deinit();
    self.display.deinit();
    self.resource_registry.deinit();
    self.controller.deinit();
    self.client.deinit();
    self.allocator.destroy(self);
}
