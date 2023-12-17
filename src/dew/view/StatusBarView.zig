const std = @import("std");
const dew = @import("../../dew.zig");

const StatusBarView = @This();

status_message: *const dew.models.StatusMessage,
width: usize,
view_event_publisher: *const dew.event.Publisher(dew.view.Event),

pub fn init(status_message: *dew.models.StatusMessage, view_event_publisher: *const dew.event.Publisher(dew.view.Event)) StatusBarView {
    return .{
        .status_message = status_message,
        .width = 0,
        .view_event_publisher = view_event_publisher,
    };
}

pub fn deinit(_: *StatusBarView) void {}

pub fn view(self: *const StatusBarView) ![]const u8 {
    return if (self.status_message.message.len < self.width)
        self.status_message.message[0..]
    else
        self.status_message.message[0..self.width];
}

pub fn eventSubscriber(self: *StatusBarView) dew.event.Subscriber(dew.models.Event) {
    return .{
        .ptr = self,
        .vtable = &.{
            .handle = handleEvent,
        },
    };
}

fn handleEvent(ctx: *anyopaque, event: dew.models.Event) anyerror!void {
    var self: *StatusBarView = @ptrCast(@alignCast(ctx));
    switch (event) {
        .status_message_updated => {
            try self.view_event_publisher.publish(.status_bar_view_updated);
        },
        else => {},
    }
}

pub fn setSize(self: *StatusBarView, width: usize) !void {
    self.width = width;
    try self.view_event_publisher.publish(.status_bar_view_updated);
}
