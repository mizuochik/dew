const CommandParser = @import("CommandParser.zig");
const Editor = @import("Editor.zig");
const UnicodeString = @import("UnicodeString.zig");
const std = @import("std");

editor: *Editor,

pub fn evaluate(self: *@This(), raw_command_line: UnicodeString) !void {
    var parser = try CommandParser.init(self.editor.allocator, &self.editor.buffer_selector, &self.editor.client.status);
    defer parser.deinit();
    var command_line = try parser.parse(raw_command_line.buffer.items);
    defer command_line.deinit();
    const command = try self.editor.resource_registry.get(command_line.method_name);
    try command(self.editor, command_line.params);
}

pub fn evaluateFormat(self: *@This(), comptime fmt: []const u8, args: anytype) !void {
    const command = try std.fmt.allocPrint(self.editor.allocator, fmt, args);
    defer self.editor.allocator.free(command);
    var command_u = try UnicodeString.init(self.editor.allocator);
    defer command_u.deinit();
    try command_u.appendSlice(command);
    try self.evaluate(command_u);
}
