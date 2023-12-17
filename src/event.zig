const std = @import("std");

pub fn Publisher(comptime E: anytype) type {
    return struct {
        subscribers: std.ArrayList(Subscriber(E)),

        pub fn init(allocator: std.mem.Allocator) Publisher(E) {
            return .{
                .subscribers = std.ArrayList(Subscriber(E)).init(allocator),
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
