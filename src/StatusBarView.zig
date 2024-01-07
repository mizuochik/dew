const std = @import("std");
const models = @import("models.zig");
const view = @import("view.zig");
const StatusMessage = @import("StatusMessage.zig");

const StatusBarView = @This();

status_message: *const StatusMessage,
width: usize,

pub fn init(status_message: *StatusMessage) StatusBarView {
    return .{
        .status_message = status_message,
        .width = 0,
    };
}

pub fn deinit(_: *StatusBarView) void {}

pub fn viewContent(self: *const StatusBarView) ![]const u8 {
    return if (self.status_message.message.len < self.width)
        self.status_message.message[0..]
    else
        self.status_message.message[0..self.width];
}

pub fn render(self: *const StatusBarView, buffer: []u8) void {
    const blank_size = if (buffer.len > self.status_message.message.len) buffer.len - self.status_message.message.len else 0;
    for (0..blank_size) |i| {
        buffer[i] = ' ';
    }
    const non_blank_size = if (buffer.len < self.status_message.message.len) buffer.len else self.status_message.message.len;
    std.mem.copy(u8, buffer[blank_size..], self.status_message.message[0..non_blank_size]);
}

fn handleEvent(_: *anyopaque, event_: models.Event) anyerror!void {
    switch (event_) {
        .status_message_updated => {},
        else => {},
    }
}

pub fn setSize(self: *StatusBarView, width: usize) !void {
    self.width = width;
}
