const std = @import("std");
const Keyboard = @import("Keyboard.zig");
const CommandLine = @import("CommandLine.zig");

pub const Error = error{
    InvalidCommand,
};

ptr: *anyopaque,
name: []const u8,
keys: std.AutoHashMap(Keyboard.Key, []const u8),
vtable: *const VTable,

pub fn runCommand(self: *@This(), arguments: [][]const u8, input: std.io.AnyReader, output: std.io.AnyWriter) anyerror!void {
    try self.vtable.apiCommand(self.ptr, arguments, input, output);
}

pub const VTable = struct {
    apiCommand: *const fn (ptr: *anyopaque, arguments: [][]const u8, input: std.io.AnyReader, output: std.io.AnyWriter) anyerror!void,
    deinit: *const fn (ptr: *anyopaque) void,
};

pub fn deinit(self: *@This()) void {
    self.vtable.deinit(self.ptr);
    self.keys.deinit();
}
