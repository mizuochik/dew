const std = @import("std");
const BufferSelector = @import("../BufferSelector.zig");
const StatusMessage = @import("../StatusMessage.zig");
const Command = @import("../Command.zig");
const Editor = @import("../Editor.zig");

const NewFile = @This();

allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) !Command {
    const cmd = try allocator.create(NewFile);
    errdefer allocator.destroy(cmd);
    cmd.* = NewFile{
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

fn run(_: *anyopaque, editor: *Editor, arguments: [][]const u8) anyerror!void {
    const want_arguments_len = 0;
    if (arguments.len != want_arguments_len) {
        const message = try std.fmt.allocPrint(editor.allocator, "invalid argument length: want {d} but {d}", .{ want_arguments_len, arguments.len });
        errdefer editor.allocator.free(message);
        try editor.status_message.setMessage(message);
        return;
    }
    const untitled_name = try std.fmt.allocPrint(editor.allocator, "Untitled", .{});
    defer editor.allocator.free(untitled_name);
    try editor.buffer_selector.openFileBuffer(untitled_name);
}
