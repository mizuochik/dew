const std = @import("std");

const Command = @This();

ptr: *anyopaque,
vtable: *const VTable,

const VTable = struct {
    run: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, arguments: [][]const u8) anyerror!void,
    deinit: *const fn (ptr: *anyopaque) void,
};

pub fn run(self: *Command, allocator: std.mem.Allocator, arguments: [][]const u8) !void {
    try self.vtable.run(self.ptr, allocator, arguments);
}

pub fn deinit(self: *const Command) void {
    self.vtable.deinit(self.ptr);
}
