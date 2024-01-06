const std = @import("std");
const BufferSelector = @import("../BufferSelector.zig");
const StatusMessage = @import("../StatusMessage.zig");
const Command = @import("../Command.zig");
const Editor = @import("../Editor.zig");

const SaveFile = @This();

allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) !Command {
    const cmd = try allocator.create(SaveFile);
    errdefer allocator.destroy(cmd);
    cmd.* = SaveFile{
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

fn run(_: *anyopaque, editor: *Editor, arguments: [][]const u8) anyerror!void {
    const want_arguments_max_len = 1;
    if (arguments.len > want_arguments_max_len) {
        const message = try std.fmt.allocPrint(editor.allocator, "invalid argument length: want <= {} but {d}", .{ want_arguments_max_len, arguments.len });
        errdefer editor.allocator.free(message);
        try editor.status_message.setMessage(message);
        return;
    }
    const file_name = switch (arguments.len) {
        0 => editor.buffer_selector.current_file_buffer,
        1 => arguments[0],
        else => {
            const message = try std.fmt.allocPrint(editor.allocator, "invalid argument length: want <= 1 but {d}", .{arguments.len});
            errdefer editor.allocator.free(message);
            try editor.status_message.setMessage(message);
            return;
        },
    };
    try editor.buffer_selector.saveFileBuffer(file_name);
}
