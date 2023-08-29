const std = @import("std");
const dew = @import("../../dew.zig");
const testing = std.testing;
const StatusBar = dew.models.StatusBar;
const Buffer = dew.models.Buffer;
const Event = dew.models.Event;
const Publisher = dew.event.Publisher(Event);
const Subscriber = dew.event.Subscriber(Event);

const StatusBarView = @This();

status_bar: *const StatusBar,
width: usize,

pub fn init(status_bar: *StatusBar) StatusBarView {
    return .{
        .status_bar = status_bar,
        .width = 0,
    };
}

pub fn deinit(_: *StatusBarView) void {}

pub fn view(self: *const StatusBarView) ![]const u8 {
    return if (self.status_bar.message.len < self.width)
        self.status_bar.message[0..]
    else
        self.status_bar.message[0..self.width];
}

pub fn eventSubscriber(self: *StatusBarView) Subscriber {
    return .{
        .ptr = self,
        .vtable = &.{
            .handle = handleEvent,
        },
    };
}

fn handleEvent(ctx: *anyopaque, event: Event) anyerror!void {
    var self: *StatusBarView = @ptrCast(@alignCast(ctx));
    switch (event) {
        .status_bar_updated => {},
        .screen_size_changed => |new_size| {
            self.width = new_size.width;
        },
        else => {},
    }
}

test "StatusBarView: view" {
    var event_publisher = Publisher.init(testing.allocator);
    defer event_publisher.deinit();
    var status_bar = try StatusBar.init(testing.allocator, &event_publisher);
    defer status_bar.deinit();
    var status_bar_view = StatusBarView.init(&status_bar);
    defer status_bar_view.deinit();
    try event_publisher.addSubscriber(status_bar_view.eventSubscriber());

    var new_message = try std.fmt.allocPrint(testing.allocator, "hello world", .{});
    try status_bar.setMessage(new_message);
    try event_publisher.publish(Event{
        .screen_size_changed = .{
            .width = 5,
            .height = 100,
        },
    });

    const actual = try status_bar_view.view();
    try testing.expectFmt("hello", "{s}", .{actual});
}
