const std = @import("std");
const dew = @import("../../dew.zig");

const Command = @This();

ptr: *anyopaque,
vtable: *const VTable,

const VTable = struct {
    run: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, arguments: [][]const u8) anyerror!void,
};

pub fn run(self: *Command, allocator: std.mem.Allocator, arguments: [][]const u8) !void {
    try self.vtable.run(self.ptr, allocator, arguments);
}

pub const OpenFile = struct {
    buffer_selector: *dew.models.BufferSelector,
    status_message: *dew.models.StatusMessage,

    fn doRun(ptr: *anyopaque, allocator: std.mem.Allocator, arguments: [][]const u8) anyerror!void {
        std.log.debug("trace: opening file", .{});

        const self: *OpenFile = @ptrCast(@alignCast(ptr));
        const want_arguments_len = 1;
        if (arguments.len != want_arguments_len) {
            const message = try std.fmt.allocPrint(allocator, "invalid argument length: want {d} but {d}", .{ want_arguments_len, arguments.len });
            errdefer allocator.free(message);
            try self.status_message.setMessage(message);
            return;
        }
        const file_path = arguments[0];
        std.log.debug("opening file: {s}", .{file_path});
        self.buffer_selector.file_buffer.openFile(file_path) catch |err| {
            switch (err) {
                error.FileNotFound => {
                    std.log.debug("cmd: cached FileNotFound", .{});
                    const message = try std.fmt.allocPrint(allocator, "file not found: {s}", .{file_path});
                    errdefer allocator.free(message);
                    try self.status_message.setMessage(message);
                },
                else => return err,
            }
        };
    }

    pub fn command(self: *OpenFile) Command {
        return .{
            .ptr = self,
            .vtable = &.{
                .run = doRun,
            },
        };
    }
};
