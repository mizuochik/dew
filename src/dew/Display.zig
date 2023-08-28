const std = @import("std");
const mem = std.mem;
const heap = std.heap;
const io = std.io;
const fmt = std.fmt;

const dew = @import("../dew.zig");
const view = dew.view;
const event = dew.event;

buffer_view: *const view.BufferView,
allocator: mem.Allocator,

const Self = @This();

pub fn eventSubscriber(self: *Self) event.EventSubscriber(view.Event) {
    return .{
        .ptr = self,
        .vtable = &.{
            .handle = handleEvent,
        },
    };
}

fn handleEvent(ctx: *anyopaque, ev: view.Event) anyerror!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    switch (ev) {
        .buffer_view_updated => {
            try self.doRender(refreshScreen);
        },
    }
}

fn doRender(self: *const Self, render: *const fn (self: *const Self, arena: mem.Allocator, buf: *std.ArrayList(u8)) anyerror!void) !void {
    var arena = heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var buf = std.ArrayList(u8).init(self.allocator);
    defer buf.deinit();
    try render(self, arena.allocator(), &buf);
    try io.getStdOut().writeAll(buf.items);
}

fn refreshScreen(self: *const Self, arena: mem.Allocator, buf: *std.ArrayList(u8)) !void {
    try buf.appendSlice("\x1b[?25l");
    try buf.appendSlice("\x1b[H");
    try self.drawRows(buf);
    const cursor = self.buffer_view.getCursor();
    const cursor_y = if (cursor.y <= self.buffer_view.y_scroll)
        0
    else
        cursor.y - self.buffer_view.y_scroll;
    try buf.appendSlice(try fmt.allocPrint(arena, "\x1b[{d};{d}H", .{ cursor_y + 1, cursor.x + 1 }));
    try buf.appendSlice("\x1b[?25h");
}

fn clearScreen(_: *const Self, _: mem.Allocator, buf: *std.ArrayList(u8)) !void {
    try buf.appendSlice("\x1b[2J");
    try buf.appendSlice("\x1b[H");
}

fn drawRows(self: *const Self, buf: *std.ArrayList(u8)) !void {
    for (0..self.buffer_view.height) |y| {
        if (y > 0) try buf.appendSlice("\r\n");
        try buf.appendSlice("\x1b[K");
        try buf.appendSlice(self.buffer_view.getRowView(y + self.buffer_view.y_scroll));
    }
    try buf.appendSlice("\r\n");
    try buf.appendSlice("\x1b[K");
    try buf.appendSlice("status");
}
