const std = @import("std");
const event = @import("event.zig");
const BufferSelector = @import("BufferSelector.zig");
const StatusMessage = @import("StatusMessage.zig");
const Event = @import("Event.zig");
const models = @import("models.zig");
const CommandParser = @import("CommandParser.zig");

const CommandEvaluator = @This();

buffer_selector: *BufferSelector,
status_message: *StatusMessage,
allocator: std.mem.Allocator,

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
            var parser = try CommandParser.init(self.allocator, self.buffer_selector, self.status_message);
            defer parser.deinit();
            var command_line = try parser.parse(command_line_s.buffer.items);
            defer command_line.deinit();
            try command_line.evaluate();
            try self.buffer_selector.toggleCommandBuffer();
        },
        else => {},
    }
}
