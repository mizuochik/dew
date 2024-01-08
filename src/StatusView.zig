const std = @import("std");
const models = @import("models.zig");
const view = @import("view.zig");
const Status = @import("Status.zig");

status: *const Status,
width: usize,

pub fn init(status: *Status) @This() {
    return .{
        .status = status,
        .width = 0,
    };
}

pub fn deinit(_: *@This()) void {}

pub fn viewContent(self: *const @This()) ![]const u8 {
    return if (self.status.message.len < self.width)
        self.status.message[0..]
    else
        self.status.message[0..self.width];
}

pub fn render(self: *const @This(), buffer: []u8) void {
    const blank_size = if (buffer.len > self.status.message.len) buffer.len - self.status.message.len else 0;
    for (0..blank_size) |i| {
        buffer[i] = ' ';
    }
    const non_blank_size = if (buffer.len < self.status.message.len) buffer.len else self.status.message.len;
    std.mem.copy(u8, buffer[blank_size..], self.status.message[0..non_blank_size]);
}

fn handleEvent(_: *anyopaque, event_: models.Event) anyerror!void {
    switch (event_) {
        .status_updated => {},
        else => {},
    }
}

pub fn setSize(self: *@This(), width: usize) !void {
    self.width = width;
}
