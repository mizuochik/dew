const std = @import("std");
const models = @import("models.zig");
const view = @import("view.zig");
const Status = @import("Status.zig");

width: usize,

pub fn init() @This() {
    return .{
        .width = 0,
    };
}

pub fn deinit(_: *@This()) void {}

pub fn render(_: *const @This(), status: *Status, buffer: []u8) void {
    const blank_size = if (buffer.len > status.message.len) buffer.len - status.message.len else 0;
    for (0..blank_size) |i| {
        buffer[i] = ' ';
    }
    const non_blank_size = if (buffer.len < status.message.len) buffer.len else status.message.len;
    std.mem.copy(u8, buffer[blank_size..], status.message[0..non_blank_size]);
}

pub fn setSize(self: *@This(), width: usize) !void {
    self.width = width;
}
