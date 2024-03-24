const Module = @This();
const std = @import("std");
const Keyboard = @import("Keyboard.zig");
const CommandLine = @import("CommandLine.zig");
const ModuleDefinition = @import("ModuleDefinition.zig");
const Command = @import("Command.zig");

pub const Error = error{
    InvalidCommand,
};

pub const VTable = struct {
    runCommand: *const fn (ptr: *anyopaque, command: *const Command, input: std.io.AnyReader, output: std.io.AnyWriter) anyerror!void,
    deinit: *const fn (ptr: *anyopaque) void,
};

ptr: *anyopaque,
definition: *const ModuleDefinition,
vtable: *const VTable,

pub fn runCommand(self: *Module, command: *const Command, input: std.io.AnyReader, output: std.io.AnyWriter) anyerror!void {
    try self.vtable.runCommand(self.ptr, command, input, output);
}

pub fn deinit(self: *const Module) void {
    self.vtable.deinit(self.ptr);
}
