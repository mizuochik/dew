const std = @import("std");
const dew = @import("../dew.zig");
const Position = dew.models.Position;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const testing = std.testing;

pub fn Publisher(comptime E: anytype) type {
    return struct {
        subscribers: ArrayList(Subscriber(E)),

        pub fn init(allocator: Allocator) Publisher(E) {
            return .{
                .subscribers = ArrayList(Subscriber(E)).init(allocator),
            };
        }

        pub fn deinit(self: *const Publisher(E)) void {
            self.subscribers.deinit();
        }

        pub fn addSubscriber(self: *Publisher(E), subscriber: Subscriber(E)) !void {
            try self.subscribers.append(subscriber);
        }

        pub fn publish(self: *const Publisher(E), event: E) !void {
            for (self.subscribers.items) |*subscriber| {
                try subscriber.handle(event);
            }
            event.deinit();
        }
    };
}

pub fn Subscriber(comptime E: anytype) type {
    return struct {
        ptr: *anyopaque,
        vtable: *const VTable,

        const VTable = struct {
            handle: *const fn (self: *anyopaque, event: E) anyerror!void,
        };

        pub fn handle(self: *Subscriber(E), event: E) anyerror!void {
            try self.vtable.handle(self.ptr, event);
        }
    };
}

const StubEvent = union(enum) {
    buffer_updated: struct {
        from: Position,
        to: Position,
    },
    status_message_updated,
};

const StubSubscriber = struct {
    subscribed: ArrayList(StubEvent),

    pub fn init(allocator: Allocator) StubSubscriber {
        return .{
            .subscribed = ArrayList(StubEvent).init(allocator),
        };
    }

    pub fn deinit(self: *StubSubscriber) void {
        self.subscribed.deinit();
    }

    pub fn subscriber(self: *StubSubscriber) Subscriber(StubEvent) {
        return .{
            .ptr = self,
            .vtable = &.{
                .handle = handle,
            },
        };
    }

    fn handle(ctx: *anyopaque, event: StubEvent) anyerror!void {
        var self: *StubSubscriber = @ptrCast(@alignCast(ctx));
        try self.subscribed.append(event);
    }
};

test "event: publish and subscribe" {
    var publisher = Publisher(StubEvent).init(testing.allocator);
    defer publisher.deinit();
    var subscriber = StubSubscriber.init(testing.allocator);
    defer subscriber.deinit();
    try publisher.addSubscriber(subscriber.subscriber());

    try publisher.publish(.status_message_updated);
    try publisher.publish(.status_message_updated);

    try testing.expectEqual(@as(usize, 2), subscriber.subscribed.items.len);
    try testing.expectEqual(StubEvent.status_message_updated, subscriber.subscribed.items[0]);
    try testing.expectEqual(StubEvent.status_message_updated, subscriber.subscribed.items[1]);
}
