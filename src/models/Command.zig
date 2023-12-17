const std = @import("std");
const BufferSelector = @import("BufferSelector.zig");
const StatusMessage = @import("StatusMessage.zig");

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

pub const OpenFile = struct {
    buffer_selector: *BufferSelector,
    status_message: *StatusMessage,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, buffer_selector: *BufferSelector, status_message: *StatusMessage) !Command {
        const cmd = try allocator.create(OpenFile);
        errdefer allocator.destroy(cmd);
        cmd.* = OpenFile{
            .buffer_selector = buffer_selector,
            .status_message = status_message,
            .allocator = allocator,
        };
        return Command{
            .ptr = cmd,
            .vtable = &.{
                .run = doRun,
                .deinit = doDeinit,
            },
        };
    }

    fn doDeinit(ptr: *anyopaque) void {
        const cmd: *OpenFile = @ptrCast(@alignCast(ptr));
        cmd.allocator.destroy(cmd);
    }

    fn doRun(ptr: *anyopaque, allocator: std.mem.Allocator, arguments: [][]const u8) anyerror!void {
        const self: *OpenFile = @ptrCast(@alignCast(ptr));
        const want_arguments_len = 1;
        if (arguments.len != want_arguments_len) {
            const message = try std.fmt.allocPrint(allocator, "invalid argument length: want {d} but {d}", .{ want_arguments_len, arguments.len });
            errdefer allocator.free(message);
            try self.status_message.setMessage(message);
            return;
        }
        const file_path = arguments[0];
        self.buffer_selector.file_buffer.openFile(file_path) catch |err| {
            switch (err) {
                error.FileNotFound => {
                    const message = try std.fmt.allocPrint(allocator, "file not found: {s}", .{file_path});
                    errdefer allocator.free(message);
                    try self.status_message.setMessage(message);
                },
                else => return err,
            }
        };
    }
};
