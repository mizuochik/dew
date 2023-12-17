const std = @import("std");
const event = @import("../event.zig");
const models = @import("../models.zig");
const BufferSelector = @import("BufferSelector.zig");
const StatusMessage = @import("StatusMessage.zig");

const CommandExecutor = @This();

buffer_selector: *BufferSelector,
status_message: *StatusMessage,
allocator: std.mem.Allocator,

pub fn eventSubscriber(self: *CommandExecutor) event.Subscriber(models.Event) {
    return .{
        .ptr = self,
        .vtable = &.{
            .handle = handleEvent,
        },
    };
}

pub fn handleEvent(ctx: *anyopaque, event_: models.Event) anyerror!void {
    const self: *CommandExecutor = @ptrCast(@alignCast(ctx));
    switch (event_) {
        .command_executed => |command_line_s| {
            var parser = try models.CommandLineParser.init(self.allocator, self.buffer_selector, self.status_message);
            defer parser.deinit();
            var command_line = try parser.parse(command_line_s.buffer.items);
            defer command_line.deinit();
            try command_line.evaluate();
            try self.buffer_selector.toggleCommandBuffer();
        },
        else => {},
    }
}
