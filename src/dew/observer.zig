const std = @import("std");
const mem = std.mem;
const testing = std.testing;

pub fn Observer(comptime E: type) type {
    return struct {
        const Self = @This();

        ptr: *anyopaque,
        vtable: *const VTable,

        pub const VTable = struct {
            handleEvent: *const fn (ctx: *anyopaque, event: E) anyerror!void,
        };

        pub fn handleEvent(self: *Self, event: E) !void {
            try self.vtable.handleEvent(self.ptr, event);
        }
    };
}

pub fn ObserverList(comptime E: type) type {
    return struct {
        const Self = @This();

        observers: std.ArrayList(Observer(E)),

        pub fn init(allocator: mem.Allocator) Self {
            return .{
                .observers = std.ArrayList(Observer(E)).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.observers.deinit();
        }

        pub fn add(self: *Self, observer: Observer(E)) !void {
            try self.observers.append(observer);
        }

        pub fn notifyEvent(self: *Self, event: E) !void {
            for (self.observers.items) |*observer| {
                try observer.handleEvent(event);
            }
        }
    };
}

const DummyEvent = union(enum) {
    some_event: []const u8,
};

const DummyObserver = struct {
    handled_events: *std.ArrayList(DummyEvent),

    fn observer(self: *DummyObserver) Observer(DummyEvent) {
        return .{
            .ptr = self,
            .vtable = &.{
                .handleEvent = handleDummyEvent,
            },
        };
    }
};

fn handleDummyEvent(ctx: *anyopaque, event: DummyEvent) anyerror!void {
    var self: *DummyObserver = @ptrCast(@alignCast(ctx));
    try self.handled_events.append(event);
}

test "observer: notifyEvent/handleEvent" {
    var handled_events = std.ArrayList(DummyEvent).init(testing.allocator);
    defer handled_events.deinit();
    var dummy_observer_list = ObserverList(DummyEvent).init(testing.allocator);
    defer dummy_observer_list.deinit();
    var dummy_observer = DummyObserver{
        .handled_events = &handled_events,
    };

    try dummy_observer_list.add(dummy_observer.observer());
    try dummy_observer_list.notifyEvent(.{ .some_event = "executed" });

    try testing.expectEqual(@as(usize, 1), handled_events.items.len);
    try testing.expectEqualStrings("executed", handled_events.items[0].some_event);
}
