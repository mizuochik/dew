const StatusView = @This();
const std = @import("std");
const Status = @import("Status.zig");
const Display = @import("Display.zig");

width: usize,

pub fn init() StatusView {
    return .{
        .width = 0,
    };
}

pub fn deinit(_: *StatusView) void {}

pub fn render(_: *const StatusView, buffer: *Display.Buffer, status: *Status) !void {
    const l_offset = buffer.height - 1;
    const c_offset = if (buffer.width > status.message.len) buffer.width - status.message.len else 0;
    for (0..@min(buffer.width, status.message.len)) |c| {
        buffer.cells[l_offset * buffer.width + c + c_offset] = .{
            .character = status.message[c],
            .foreground = .default,
            .background = .default,
        };
    }
}

pub fn setSize(self: *StatusView, width: usize) !void {
    self.width = width;
}
