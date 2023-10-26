const std = @import("std");
const dew = @import("../../dew.zig");

const Self = @This();

pub fn init() Self {
    return .{};
}

pub fn deinit(_: *const Self) void {}

pub fn eventSubscriber(self: *Self) dew.event.Subscriber(dew.models.Event) {
    return .{
        .ptr = self,
        .vtable = &.{
            .handle = handleEvent,
        },
    };
}

pub fn handleEvent(ctx: *anyopaque, event: dew.models.Event) anyerror!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    _ = self;
    switch (event) {
        .command_executed => |cmd| {
            std.log.info("cmd = {s}", .{cmd.buffer.items});
        },
        else => {},
    }
}
