const dew = @import("../../dew.zig");
const Position = dew.models.Position;

pub const Observer = struct {
    ptr: *anyopaque,
    vtable: VTable,

    const VTable = struct {
        update: *const fn (self: *anyopaque, event: *const Event) anyerror!void,
    };

    pub fn update(self: *Observer, event: *const Event) anyerror!void {
        try self.vtable.update(self.ptr, event);
    }
};

pub const Event = union(enum) {
    buffer_updated: struct {
        from: Position,
        to: Position,
    },
    status_bar_updated,
};
