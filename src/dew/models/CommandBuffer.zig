const std = @import("std");
const mem = std.mem;
const dew = @import("../../dew.zig");
const event = dew.event;

const models = dew.models;

inner_buffer: *models.Buffer,
inner_event_publisher: *event.Publisher(models.Event),
event_publisher: *event.Publisher(models.Event),
allocator: mem.Allocator,

const Self = @This();

pub fn init(allocator: mem.Allocator, event_publisher: *event.Publisher(models.Event)) !Self {
    var inner_publisher = try allocator.create(event.Publisher(models.Event));
    errdefer allocator.destroy(inner_publisher);
    inner_publisher.* = event.Publisher(models.Event).init(allocator);
    errdefer inner_publisher.deinit();
    var inner_buffer = try allocator.create(models.Buffer);
    errdefer allocator.destroy(inner_buffer);
    inner_buffer.* = models.Buffer.init(allocator, inner_publisher);
    errdefer inner_buffer.deinit();
    return .{
        .inner_buffer = inner_buffer,
        .inner_event_publisher = inner_publisher,
        .event_publisher = event_publisher,
        .allocator = allocator,
    };
}

pub fn deinit(self: *const Self) void {
    self.inner_event_publisher.deinit();
    self.allocator.destroy(self.inner_event_publisher);
    self.inner_buffer.deinit();
    self.allocator.destroy(self.inner_buffer);
}
