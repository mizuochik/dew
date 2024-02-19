const std = @import("std");
const Keyboard = @import("Keyboard.zig");
const CommandLine = @import("CommandLine.zig");

ptr: *anyopaque,
name: []const u8,
api: struct {
    command: *const fn (ptr: *anyopaque, arguments: [][]const u8) anyerror!void,
},
keys: std.AutoHashMap(Keyboard.Key, CommandLine),
