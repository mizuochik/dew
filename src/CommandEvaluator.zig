const std = @import("std");
const event = @import("event.zig");
const BufferSelector = @import("BufferSelector.zig");
const StatusMessage = @import("StatusMessage.zig");
const Event = @import("Event.zig");
const models = @import("models.zig");
const CommandParser = @import("CommandParser.zig");
const Editor = @import("Editor.zig");

const CommandEvaluator = @This();

editor: *Editor,

pub fn eventSubscriber(self: *CommandEvaluator) event.Subscriber(models.Event) {
    return .{
        .ptr = self,
        .vtable = &.{
            .handle = handleEvent,
        },
    };
}

pub fn handleEvent(ctx: *anyopaque, event_: models.Event) anyerror!void {
    const self: *CommandEvaluator = @ptrCast(@alignCast(ctx));
    switch (event_) {
        .command_executed => |command_line_s| {
            var parser = try CommandParser.init(self.editor.allocator, self.editor.buffer_selector, self.editor.status_message);
            defer parser.deinit();
            var command_line = try parser.parse(command_line_s.buffer.items);
            defer command_line.deinit();
            try command_line.command.run(self.editor, command_line.arguments);
            try self.editor.buffer_selector.toggleCommandBuffer();
        },
        else => {},
    }
}
