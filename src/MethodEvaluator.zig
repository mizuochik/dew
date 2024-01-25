const MethodParser = @import("MethodParser.zig");
const Editor = @import("Editor.zig");
const UnicodeString = @import("UnicodeString.zig");

editor: *Editor,

pub fn evaluate(self: *@This(), raw_method_line: UnicodeString) !void {
    var parser = try MethodParser.init(self.editor.allocator, &self.editor.buffer_selector, &self.editor.client.status);
    defer parser.deinit();
    var method_line = try parser.parse(raw_method_line.buffer.items);
    defer method_line.deinit();
    const command = try self.editor.resource_registry.get(method_line.method_name);
    try command(self.editor, method_line.params);
    try self.editor.client.toggleMethodLine();
}
