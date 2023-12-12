const std = @import("std");
const dew = @import("../../dew.zig");

const CommandExecutor = @This();

buffer_selector: *dew.models.BufferSelector,
status_message: *dew.models.StatusMessage,
allocator: std.mem.Allocator,

pub fn eventSubscriber(self: *CommandExecutor) dew.event.Subscriber(dew.models.Event) {
    return .{
        .ptr = self,
        .vtable = &.{
            .handle = handleEvent,
        },
    };
}

pub fn handleEvent(ctx: *anyopaque, event: dew.models.Event) anyerror!void {
    const self: *CommandExecutor = @ptrCast(@alignCast(ctx));
    switch (event) {
        .command_executed => |command_line_s| {
            var parser = try dew.models.CommandLineParser.init(self.allocator, self.buffer_selector, self.status_message);
            defer parser.deinit();
            var command_line = try parser.parse(command_line_s.buffer.items);
            defer command_line.deinit();
            try command_line.evaluate();
            try self.buffer_selector.toggleCommandBuffer();
        },
        else => {},
    }
}
