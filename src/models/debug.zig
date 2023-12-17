const std = @import("std");
const BufferSelector = @import("BufferSelector.zig");
const event = @import("../event.zig");
const models = @import("../models.zig");

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
        var cursor_positions = std.ArrayList(models.Position).init(self.allocator);
        defer cursor_positions.deinit();
        for (self.buffer_selector.current_buffer.cursors.items) |*cursor| {
            try cursor_positions.append(cursor.getPosition());
        }
        std.log.debug("event = {}, mode = {}, cursor_positions = {any}", .{
            event_,
            self.buffer_selector.current_buffer.mode,
            cursor_positions.items,
        });
    }
};
