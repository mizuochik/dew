const Editor = @This();
const std = @import("std");
const Keyboard = @import("Keyboard.zig");
const Terminal = @import("Terminal.zig");
const Display = @import("Display.zig");
const CommandEvaluator = @import("CommandEvaluator.zig");
const KeyEvaluator = @import("KeyEvaluator.zig");
const BufferSelector = @import("BufferSelector.zig");
const Status = @import("Status.zig");
const Client = @import("Client.zig");
const TextView = @import("TextView.zig");
const StatusView = @import("StatusView.zig");
const DisplaySize = @import("DisplaySize.zig");
const ResourceRegistry = @import("ResourceRegistry.zig");
const ModuleRegistry = @import("ModuleRegistry.zig");

pub const Options = struct {
    is_debug: bool = false,
};

allocator: std.mem.Allocator,
edit_view: TextView,
command_ref_view: TextView,
buffer_selector: BufferSelector,
status_view: StatusView,
display_size: DisplaySize,
command_evaluator: CommandEvaluator,
key_evaluator: KeyEvaluator,
resource_registry: ResourceRegistry,
module_registry: ModuleRegistry,
keyboard: Keyboard,
terminal: Terminal,
client: Client,
display: Display,

pub fn init(allocator: std.mem.Allocator, _: Options) !*Editor {
    const editor = try allocator.create(Editor);
    errdefer allocator.destroy(editor);

    editor.allocator = allocator;

    editor.client = try Client.init(allocator);
    errdefer editor.client.deinit();

    editor.buffer_selector = try BufferSelector.init(allocator, editor);
    errdefer editor.buffer_selector.deinit();

    editor.edit_view = TextView.init(allocator, editor, .file);
    errdefer editor.edit_view.deinit();

    editor.command_ref_view = TextView.init(allocator, editor, .command);
    errdefer editor.command_ref_view.deinit();

    editor.status_view = StatusView.init();
    errdefer editor.status_view.deinit();

    editor.display_size = DisplaySize.init();
    editor.display = try Display.init(allocator, &editor.edit_view, &editor.status_view, &editor.command_ref_view, &editor.client, &editor.display_size);
    errdefer editor.display.deinit();

    editor.command_evaluator = .{
        .editor = editor,
    };

    editor.key_evaluator = KeyEvaluator.init(allocator, editor);
    errdefer editor.key_evaluator.deinit();
    try editor.key_evaluator.installDefaultKeyMap();

    editor.resource_registry = ResourceRegistry.init(allocator);
    errdefer editor.resource_registry.deinit();
    try editor.resource_registry.registerBuiltinResources();

    editor.module_registry = ModuleRegistry.init(editor);
    errdefer editor.module_registry.deinit();
    try editor.module_registry.appendBuiltinModules();

    editor.keyboard = .{};
    editor.terminal = .{};

    return editor;
}

pub fn deinit(self: *Editor) void {
    self.edit_view.deinit();
    self.command_ref_view.deinit();
    self.buffer_selector.deinit();
    self.status_view.deinit();
    self.display.deinit();
    self.resource_registry.deinit();
    self.module_registry.deinit();
    self.key_evaluator.deinit();
    self.client.deinit();
    self.allocator.destroy(self);
}
