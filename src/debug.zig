const std = @import("std");
const BufferSelector = @import("BufferSelector.zig");
const event = @import("event.zig");
const models = @import("models.zig");
const Position = @import("Position.zig");

pub const Handler = struct {
    buffer_selector: *const BufferSelector,
    allocator: std.mem.Allocator,

    pub fn eventSubscriber(self: *Handler) event.Subscriber(models.Event) {
        return .{
            .ptr = self,
            .vtable = &.{
                .handle = handleEvent,
            },
        };
    }

    fn handleEvent(ptr: *anyopaque, event_: models.Event) anyerror!void {
        const self: *Handler = @ptrCast(@alignCast(ptr));
        var cursor_positions = std.ArrayList(Position).init(self.allocator);
        defer cursor_positions.deinit();
        for (self.buffer_selector.getCurrentBuffer().cursors.items) |*cursor| {
            try cursor_positions.append(cursor.getPosition());
        }
        std.log.debug("event = {}, mode = {}, cursor_positions = {any}", .{
            event_,
            self.buffer_selector.getCurrentBuffer().mode,
            cursor_positions.items,
        });
    }
};
