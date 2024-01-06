const std = @import("std");
const Buffer = @import("../Buffer.zig");
const BufferSelector = @import("../BufferSelector.zig");
const StatusMessage = @import("../StatusMessage.zig");
const Command = @import("../Command.zig");

const OpenFile = @This();

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
            .run = run,
            .deinit = deinit,
        },
    };
}

fn deinit(ptr: *anyopaque) void {
    const cmd: *OpenFile = @ptrCast(@alignCast(ptr));
    cmd.allocator.destroy(cmd);
}

fn run(ptr: *anyopaque, allocator: std.mem.Allocator, arguments: [][]const u8) anyerror!void {
    const self: *OpenFile = @ptrCast(@alignCast(ptr));
    const want_arguments_len = 1;
    if (arguments.len != want_arguments_len) {
        const message = try std.fmt.allocPrint(allocator, "invalid argument length: want {d} but {d}", .{ want_arguments_len, arguments.len });
        errdefer allocator.free(message);
        try self.status_message.setMessage(message);
        return;
    }
    const file_path = arguments[0];
    try self.buffer_selector.openFileBuffer(file_path);
}
