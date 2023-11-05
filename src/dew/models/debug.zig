const std = @import("std");
const dew = @import("../../dew.zig");

pub const Handler = struct {
    buffer_selector: *const dew.models.BufferSelector,
    allocator: std.mem.Allocator,

    pub fn eventSubscriber(self: *Handler) dew.event.Subscriber(dew.models.Event) {
        return .{
            .ptr = self,
            .vtable = &.{
                .handle = handleEvent,
            },
        };
    }

    fn handleEvent(ptr: *anyopaque, event: dew.models.Event) anyerror!void {
        const self: *Handler = @ptrCast(@alignCast(ptr));
        var cursor_positions = std.ArrayList(dew.models.Position).init(self.allocator);
        defer cursor_positions.deinit();
        for (self.buffer_selector.current_buffer.cursors.items) |*cursor| {
            try cursor_positions.append(cursor.getPosition());
        }
        std.log.debug("event = {}, mode = {}, cursor_positions = {any}", .{
            event,
            self.buffer_selector.current_buffer.mode,
            cursor_positions.items,
        });
    }
};
