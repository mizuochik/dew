const std = @import("std");
const BufferSelector = @import("../BufferSelector.zig");
const StatusMessage = @import("../StatusMessage.zig");
const Command = @import("../Command.zig");

const SaveFile = @This();

buffer_selector: *BufferSelector,
status_message: *StatusMessage,
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator, buffer_selector: *BufferSelector, status_message: *StatusMessage) !Command {
    const cmd = try allocator.create(SaveFile);
    errdefer allocator.destroy(cmd);
    cmd.* = SaveFile{
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
    const cmd: *SaveFile = @ptrCast(@alignCast(ptr));
    cmd.allocator.destroy(cmd);
}

fn run(ptr: *anyopaque, allocator: std.mem.Allocator, arguments: [][]const u8) anyerror!void {
    const self: *SaveFile = @ptrCast(@alignCast(ptr));
    const want_arguments_max_len = 1;
    if (arguments.len > want_arguments_max_len) {
        const message = try std.fmt.allocPrint(allocator, "invalid argument length: want <= {} but {d}", .{ want_arguments_max_len, arguments.len });
        errdefer allocator.free(message);
        try self.status_message.setMessage(message);
        return;
    }
    const file_name = switch (arguments.len) {
        0 => self.buffer_selector.current_file_buffer,
        1 => arguments[0],
        else => {
            const message = try std.fmt.allocPrint(allocator, "invalid argument length: want <= 1 but {d}", .{arguments.len});
            errdefer allocator.free(message);
            try self.status_message.setMessage(message);
            return;
        },
    };
    try self.buffer_selector.saveFileBuffer(file_name);
}
