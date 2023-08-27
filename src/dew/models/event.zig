const std = @import("std");
const dew = @import("../../dew.zig");
const Position = dew.models.Position;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const testing = std.testing;

pub const Event = union(enum) {
    buffer_updated: struct {
        from: Position,
        to: Position,
    },
    status_bar_updated,
};

pub const EventPublisher = struct {
    subscribers: ArrayList(EventSubscriber),

    pub fn init(allocator: Allocator) EventPublisher {
        return .{
            .subscribers = ArrayList(EventSubscriber).init(allocator),
        };
    }

    pub fn deinit(self: *const EventPublisher) void {
        self.subscribers.deinit();
    }

    pub fn addSubscriber(self: *EventPublisher, subscriber: EventSubscriber) !void {
        try self.subscribers.append(subscriber);
    }

    pub fn publish(self: *const EventPublisher, event: Event) !void {
        for (self.subscribers.items) |*subscriber| {
            try subscriber.handle(event);
        }
    }
};

pub const EventSubscriber = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    const VTable = struct {
        handle: *const fn (self: *anyopaque, event: Event) anyerror!void,
    };

    pub fn handle(self: *EventSubscriber, event: Event) anyerror!void {
        try self.vtable.handle(self.ptr, event);
    }
};

const StubEventSubscriber = struct {
    subscribed: ArrayList(Event),

    pub fn init(allocator: Allocator) StubEventSubscriber {
        return .{
            .subscribed = ArrayList(Event).init(allocator),
        };
    }

    pub fn deinit(self: *StubEventSubscriber) void {
        self.subscribed.deinit();
    }

    pub fn subscriber(self: *StubEventSubscriber) EventSubscriber {
        return .{
            .ptr = self,
            .vtable = &.{
                .handle = handle,
            },
        };
    }

    fn handle(ctx: *anyopaque, event: Event) anyerror!void {
        var self: *StubEventSubscriber = @ptrCast(@alignCast(ctx));
        try self.subscribed.append(event);
    }
};

test "event: publish and subscribe" {
    var publisher = EventPublisher.init(testing.allocator);
    defer publisher.deinit();
    var subscriber = StubEventSubscriber.init(testing.allocator);
    defer subscriber.deinit();
    try publisher.addSubscriber(subscriber.subscriber());

    try publisher.publish(.status_bar_updated);
    try publisher.publish(.status_bar_updated);

    try testing.expectEqual(@as(usize, 2), subscriber.subscribed.items.len);
    try testing.expectEqual(Event.status_bar_updated, subscriber.subscribed.items[0]);
    try testing.expectEqual(Event.status_bar_updated, subscriber.subscribed.items[1]);
}
