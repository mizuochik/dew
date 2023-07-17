const std = @import("std");
const mem = std.mem;
const dew = @import("../dew.zig");

const v = mem.Allocator;

const View = @This();

ptr: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    update: *const fn (self: *anyopaque) anyerror!void,
};

pub fn update(self: *const View) anyerror!void {
    try self.vtable.update(self.ptr);
}
