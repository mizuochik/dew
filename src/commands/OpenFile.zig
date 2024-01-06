const std = @import("std");
const Buffer = @import("../Buffer.zig");
const BufferSelector = @import("../BufferSelector.zig");
const StatusMessage = @import("../StatusMessage.zig");
const Command = @import("../Command.zig");
const Editor = @import("../Editor.zig");

const OpenFile = @This();

allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) !Command {
    const cmd = try allocator.create(OpenFile);
    errdefer allocator.destroy(cmd);
    cmd.* = OpenFile{
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

fn run(_: *anyopaque, editor: *Editor, arguments: [][]const u8) anyerror!void {
    const want_arguments_len = 1;
    if (arguments.len != want_arguments_len) {
        const message = try std.fmt.allocPrint(editor.allocator, "invalid argument length: want {d} but {d}", .{ want_arguments_len, arguments.len });
        errdefer editor.allocator.free(message);
        try editor.status_message.setMessage(message);
        return;
    }
    const file_path = arguments[0];
    try editor.buffer_selector.openFileBuffer(file_path);
}
