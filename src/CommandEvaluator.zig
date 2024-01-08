const CommandParser = @import("CommandParser.zig");
const Editor = @import("Editor.zig");
const UnicodeString = @import("UnicodeString.zig");

const CommandEvaluator = @This();

editor: *Editor,

pub fn evaluate(self: *CommandEvaluator, raw_command_line: UnicodeString) !void {
    var parser = try CommandParser.init(self.editor.allocator, &self.editor.buffer_selector, &self.editor.status);
    defer parser.deinit();
    var command_line = try parser.parse(raw_command_line.buffer.items);
    defer command_line.deinit();
    const command = try self.editor.command_registry.get(command_line.command_name);
    try command(self.editor, command_line.arguments);
    try self.editor.buffer_selector.toggleCommandBuffer();
}
