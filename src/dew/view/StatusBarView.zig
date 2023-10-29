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
        .screen_size_changed => |new_size| {
            self.width = new_size.width;
            try self.view_event_publisher.publish(.status_bar_view_updated);
        },
        else => {},
    }
}

test "StatusBarView: view" {
    var event_publisher = dew.event.Publisher(dew.models.Event).init(std.testing.allocator);
    defer event_publisher.deinit();
    var view_event_publisher = dew.event.Publisher(dew.view.Event).init(std.testing.allocator);
    defer view_event_publisher.deinit();

    var status_message = try dew.models.StatusMessage.init(std.testing.allocator, &event_publisher);
    defer status_message.deinit();
    var status_bar_view = StatusBarView.init(
        &status_message,
        &view_event_publisher,
    );
    defer status_bar_view.deinit();
    try event_publisher.addSubscriber(status_bar_view.eventSubscriber());

    var new_message = try std.fmt.allocPrint(std.testing.allocator, "hello world", .{});
    try status_message.setMessage(new_message);
    try event_publisher.publish(dew.models.Event{
        .screen_size_changed = .{
            .width = 5,
            .height = 100,
        },
    });

    const actual = try status_bar_view.view();
    try std.testing.expectFmt("hello", "{s}", .{actual});
}
