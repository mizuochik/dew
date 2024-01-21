const MethodParser = @import("MethodParser.zig");
const Editor = @import("Editor.zig");
const UnicodeString = @import("UnicodeString.zig");

editor: *Editor,

pub fn evaluate(self: *@This(), raw_method_line: UnicodeString) !void {
    var parser = try MethodParser.init(self.editor.allocator, &self.editor.buffer_selector, &self.editor.client.status);
    defer parser.deinit();
    var command_line = try parser.parse(raw_method_line.buffer.items);
    defer command_line.deinit();
    const command = try self.editor.resource_registry.get(command_line.command_name);
    try command(self.editor, command_line.arguments);
    try self.editor.client.toggleCommandLine();
}
