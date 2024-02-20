const std = @import("std");
const Keyboard = @import("Keyboard.zig");
const CommandLine = @import("CommandLine.zig");

pub const Error = error{
    InvalidCommand,
};

ptr: *anyopaque,
name: []const u8,
api: struct {
    command: *const fn (ptr: *anyopaque, arguments: [][]const u8, input: std.io.AnyReader, output: std.io.AnyWriter) anyerror!void,
},
keys: std.AutoHashMap(Keyboard.Key, []const u8),
vtable: *const VTable,

pub const VTable = struct {
    deinit: *const fn (ptr: *anyopaque) void,
};

pub fn deinit(self: *@This()) void {
    self.vtable.deinit(self.ptr);
    self.keys.deinit();
}
