const std = @import("std");
const Editor = @import("Editor.zig");

const Command = @This();

ptr: *anyopaque,
vtable: *const VTable,

const VTable = struct {
    run: *const fn (ptr: *anyopaque, editor: *Editor, arguments: [][]const u8) anyerror!void,
    deinit: *const fn (ptr: *anyopaque) void,
};

pub fn run(self: *Command, editor: *Editor, arguments: [][]const u8) !void {
    try self.vtable.run(self.ptr, editor, arguments);
}

pub fn deinit(self: *const Command) void {
    self.vtable.deinit(self.ptr);
}
