const std = @import("std");
const dew = @import("../../dew.zig");
const models = dew.models;
const observer = dew.observer;
const testing = std.testing;
const StatusMessage = dew.models.StatusMessage;
const Buffer = dew.models.Buffer;
const Event = dew.models.Event;
const ViewEventPublisher = dew.event.Publisher(dew.view.Event);
const Publisher = dew.event.Publisher(Event);
const Subscriber = dew.event.Subscriber(Event);

const StatusBarView = @This();

status_message: *const StatusMessage,
width: usize,
view_event_publisher: *const ViewEventPublisher,

pub fn init(status_message: *StatusMessage, view_event_publisher: *const ViewEventPublisher) StatusBarView {
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

pub fn displaySizeObserver(self: *StatusBarView) observer.Observer(models.DisplaySize.Event) {
    return .{
        .ptr = self,
        .vtable = &.{
            .handleEvent = handleDisplaySizeEvent,
        },
    };
}

fn handleDisplaySizeEvent(ctx: *anyopaque, event: models.DisplaySize.Event) anyerror!void {
    var self: *StatusBarView = @ptrCast(@alignCast(ctx));
    switch (event) {
        .changed => |new_size| {
            self.width = new_size.cols;
            // try self.view_event_publisher.publish(.status_bar_view_updated);
        },
    }
}

test "StatusBarView: view" {
    var event_publisher = Publisher.init(testing.allocator);
    defer event_publisher.deinit();
    var view_event_publisher = dew.event.Publisher(dew.view.Event).init(testing.allocator);
    defer view_event_publisher.deinit();

    var status_message = try StatusMessage.init(testing.allocator, &event_publisher);
    defer status_message.deinit();
    var status_bar_view = StatusBarView.init(
        &status_message,
        &view_event_publisher,
    );
    defer status_bar_view.deinit();
    try event_publisher.addSubscriber(status_bar_view.eventSubscriber());

    var new_message = try std.fmt.allocPrint(testing.allocator, "hello world", .{});
    try status_message.setMessage(new_message);
    try event_publisher.publish(Event{
        .screen_size_changed = .{
            .width = 5,
            .height = 100,
        },
    });

    const actual = try status_bar_view.view();
    try testing.expectFmt("hello", "{s}", .{actual});
}
