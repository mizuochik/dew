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

pub const Sender = struct {
    receivers: ArrayList(Receiver),

    pub fn init(allocator: Allocator) Sender {
        return .{
            .receivers = ArrayList(Receiver).init(allocator),
        };
    }

    pub fn deinit(self: *const Sender) void {
        self.receivers.deinit();
    }

    pub fn addReceiver(self: *Sender, receiver: Receiver) !void {
        try self.receivers.append(receiver);
    }

    pub fn send(self: *const Sender, event: Event) !void {
        for (self.receivers.items) |*receiver| {
            try receiver.receive(event);
        }
    }
};

pub const Receiver = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    const VTable = struct {
        receive: *const fn (self: *anyopaque, event: Event) anyerror!void,
    };

    pub fn receive(self: *Receiver, event: Event) anyerror!void {
        try self.vtable.receive(self.ptr, event);
    }
};

const StubReceiver = struct {
    received: ArrayList(Event),

    pub fn init(allocator: Allocator) StubReceiver {
        return .{
            .received = ArrayList(Event).init(allocator),
        };
    }

    pub fn deinit(self: *StubReceiver) void {
        self.received.deinit();
    }

    pub fn receiver(self: *StubReceiver) Receiver {
        return .{
            .ptr = self,
            .vtable = &.{
                .receive = receive,
            },
        };
    }

    fn receive(ctx: *anyopaque, event: Event) anyerror!void {
        var self = @ptrCast(*StubReceiver, @alignCast(@alignOf(StubReceiver), ctx));
        try self.received.append(event);
    }
};

test "event: send and receive" {
    var sender = Sender.init(testing.allocator);
    defer sender.deinit();
    var receiver = StubReceiver.init(testing.allocator);
    defer receiver.deinit();
    try sender.addReceiver(receiver.receiver());

    try sender.send(.status_bar_updated);
    try sender.send(.status_bar_updated);

    try testing.expectEqual(@as(usize, 2), receiver.received.items.len);
    try testing.expectEqual(Event.status_bar_updated, receiver.received.items[0]);
    try testing.expectEqual(Event.status_bar_updated, receiver.received.items[1]);
}
