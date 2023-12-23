const std = @import("std");
const BufferSelector = @import("../BufferSelector.zig");
const StatusMessage = @import("../StatusMessage.zig");
const Command = @import("../Command.zig");

const NewFile = @This();

buffer_selector: *BufferSelector,
status_message: *StatusMessage,
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator, buffer_selector: *BufferSelector, status_message: *StatusMessage) !Command {
    const cmd = try allocator.create(NewFile);
    errdefer allocator.destroy(cmd);
    cmd.* = NewFile{
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
    const cmd: *NewFile = @ptrCast(@alignCast(ptr));
    cmd.allocator.destroy(cmd);
}

fn run(ptr: *anyopaque, allocator: std.mem.Allocator, arguments: [][]const u8) anyerror!void {
    const self: *NewFile = @ptrCast(@alignCast(ptr));
    const want_arguments_len = 0;
    if (arguments.len != want_arguments_len) {
        const message = try std.fmt.allocPrint(allocator, "invalid argument length: want {d} but {d}", .{ want_arguments_len, arguments.len });
        errdefer allocator.free(message);
        try self.status_message.setMessage(message);
        return;
    }
    const untitled_name = try std.fmt.allocPrint(self.allocator, "Untitled", .{});
    errdefer self.allocator.free(untitled_name);
    try self.buffer_selector.openFileBuffer(untitled_name);
}
