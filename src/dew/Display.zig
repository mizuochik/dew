const std = @import("std");
const mem = std.mem;
const heap = std.heap;
const io = std.io;
const fmt = std.fmt;

const dew = @import("../dew.zig");
const view = dew.view;
const event = dew.event;
const Editor = dew.Editor;

buffer_view: *const view.BufferView,
status_bar_view: *const view.StatusBarView,
command_buffer_view: *const view.BufferView,
allocator: mem.Allocator,
size: Editor.WindowSize,

const Self = @This();

pub fn eventSubscriber(self: *Self) event.Subscriber(view.Event) {
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
        .status_bar_view_updated => {
            try self.doRender(updateStatusBar);
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
    try self.hideCursor(buf);
    try self.putCursor(arena, buf, 0, 0);
    try self.drawRows(buf);
    try self.putCurrentCursor(arena, buf);
    try self.showCursor(buf);
}

fn hideCursor(_: *const Self, buf: *std.ArrayList(u8)) !void {
    try buf.appendSlice("\x1b[?25l");
}

fn showCursor(_: *const Self, buf: *std.ArrayList(u8)) !void {
    try buf.appendSlice("\x1b[?25h");
}

fn putCursor(_: *const Self, arena: mem.Allocator, buf: *std.ArrayList(u8), x: usize, y: usize) !void {
    try buf.appendSlice(try fmt.allocPrint(arena, "\x1b[{d};{d}H", .{ y + 1, x + 1 }));
}

fn putCurrentCursor(self: *const Self, arena: mem.Allocator, buf: *std.ArrayList(u8)) !void {
    const cursor = self.buffer_view.getCursor();
    const cursor_y = if (cursor.y <= self.buffer_view.y_scroll)
        0
    else
        cursor.y - self.buffer_view.y_scroll;
    try self.putCursor(arena, buf, cursor.x, cursor_y);
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
}

fn updateStatusBar(self: *const Self, arena: mem.Allocator, buf: *std.ArrayList(u8)) !void {
    try self.hideCursor(buf);
    try self.putCursor(arena, buf, 0, self.size.rows - 1);
    try buf.appendSlice("\x1b[K");
    try buf.appendSlice(try self.status_bar_view.view());
    try self.putCurrentCursor(arena, buf);
    try self.showCursor(buf);
}
