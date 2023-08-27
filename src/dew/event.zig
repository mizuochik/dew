const std = @import("std");
const dew = @import("../dew.zig");
const Position = dew.models.Position;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const testing = std.testing;

pub fn EventPublisher(comptime E: anytype) type {
    return struct {
        const Self = @This();

        subscribers: ArrayList(EventSubscriber(E)),

        pub fn init(allocator: Allocator) Self {
            return .{
                .subscribers = ArrayList(EventSubscriber(E)).init(allocator),
            };
        }

        pub fn deinit(self: *const Self) void {
            self.subscribers.deinit();
        }

        pub fn addSubscriber(self: *Self, subscriber: EventSubscriber(E)) !void {
            try self.subscribers.append(subscriber);
        }

        pub fn publish(self: *const Self, event: E) !void {
            for (self.subscribers.items) |*subscriber| {
                try subscriber.handle(event);
            }
        }
    };
}

pub fn EventSubscriber(comptime E: anytype) type {
    return struct {
        ptr: *anyopaque,
        vtable: *const VTable,

        const VTable = struct {
            handle: *const fn (self: *anyopaque, event: E) anyerror!void,
        };

        pub fn handle(self: *EventSubscriber(E), event: E) anyerror!void {
            try self.vtable.handle(self.ptr, event);
        }
    };
}

const StubEvent = union(enum) {
    buffer_updated: struct {
        from: Position,
        to: Position,
    },
    status_bar_updated,
};

const StubEventSubscriber = struct {
    subscribed: ArrayList(StubEvent),

    pub fn init(allocator: Allocator) StubEventSubscriber {
        return .{
            .subscribed = ArrayList(StubEvent).init(allocator),
        };
    }

    pub fn deinit(self: *StubEventSubscriber) void {
        self.subscribed.deinit();
    }

    pub fn subscriber(self: *StubEventSubscriber) EventSubscriber(StubEvent) {
        return .{
            .ptr = self,
            .vtable = &.{
                .handle = handle,
            },
        };
    }

    fn handle(ctx: *anyopaque, event: StubEvent) anyerror!void {
        var self: *StubEventSubscriber = @ptrCast(@alignCast(ctx));
        try self.subscribed.append(event);
    }
};

test "event: publish and subscribe" {
    var publisher = EventPublisher(StubEvent).init(testing.allocator);
    defer publisher.deinit();
    var subscriber = StubEventSubscriber.init(testing.allocator);
    defer subscriber.deinit();
    try publisher.addSubscriber(subscriber.subscriber());

    try publisher.publish(.status_bar_updated);
    try publisher.publish(.status_bar_updated);

    try testing.expectEqual(@as(usize, 2), subscriber.subscribed.items.len);
    try testing.expectEqual(StubEvent.status_bar_updated, subscriber.subscribed.items[0]);
    try testing.expectEqual(StubEvent.status_bar_updated, subscriber.subscribed.items[1]);
}
