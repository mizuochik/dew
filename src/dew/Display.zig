const std = @import("std");
const dew = @import("../dew.zig");

buffer_view: *const dew.view.BufferView,
status_bar_view: *const dew.view.StatusBarView,
command_buffer_view: *const dew.view.BufferView,
allocator: std.mem.Allocator,
size: dew.Editor.WindowSize,

const Display = @This();

pub fn eventSubscriber(self: *Display) dew.event.Subscriber(dew.view.Event) {
    return .{
        .ptr = self,
        .vtable = &.{
            .handle = handleEvent,
        },
    };
}

fn handleEvent(ctx: *anyopaque, ev: dew.view.Event) anyerror!void {
    const self: *Display = @ptrCast(@alignCast(ctx));
    switch (ev) {
        .buffer_view_updated => {
            try self.doRender(refreshScreen);
        },
        .command_buffer_view_updated => {
            try self.doRender(refreshBottomLine);
        },
        .status_bar_view_updated => {
            try self.doRender(refreshBottomLine);
        },
    }
}

fn doRender(self: *const Display, render: *const fn (self: *const Display, arena: std.mem.Allocator, buf: *std.ArrayList(u8)) anyerror!void) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var buf = std.ArrayList(u8).init(self.allocator);
    defer buf.deinit();
    try render(self, arena.allocator(), &buf);
    try std.io.getStdOut().writeAll(buf.items);
}

fn refreshScreen(self: *const Display, arena: std.mem.Allocator, buf: *std.ArrayList(u8)) !void {
    try self.hideCursor(buf);
    try self.putCursor(arena, buf, 0, 0);
    try self.drawRows(buf);
    try self.putCurrentCursor(arena, buf);
    try self.showCursor(buf);
}

fn refreshBottomLine(self: *const Display, arena: std.mem.Allocator, buf: *std.ArrayList(u8)) !void {
    try self.hideCursor(buf);
    try self.putCursor(arena, buf, 0, self.size.rows - 1);

    const status_bar = try self.status_bar_view.view();
    const command_buffer = self.command_buffer_view.viewRow(0);

    try buf.appendSlice("\x1b[K");
    try buf.appendSlice(command_buffer);
    const status_offset = if (self.size.cols >= command_buffer.len + status_bar.len) 0 else self.size.cols - (command_buffer.len + status_bar.len);
    if (status_offset == 0) {
        const blank = try arena.alloc(u8, self.size.cols - (command_buffer.len + status_bar.len));
        for (0..blank.len) |i| {
            blank[i] = ' ';
        }
        try buf.appendSlice(blank);
    }
    try buf.appendSlice(status_bar[status_offset..]);

    try self.putCurrentCursor(arena, buf);
    try self.showCursor(buf);
}

fn hideCursor(_: *const Display, buf: *std.ArrayList(u8)) !void {
    try buf.appendSlice("\x1b[?25l");
}

fn showCursor(_: *const Display, buf: *std.ArrayList(u8)) !void {
    try buf.appendSlice("\x1b[?25h");
}

fn putCursor(_: *const Display, arena: std.mem.Allocator, buf: *std.ArrayList(u8), x: usize, y: usize) !void {
    try buf.appendSlice(try std.fmt.allocPrint(arena, "\x1b[{d};{d}H", .{ y + 1, x + 1 }));
}

fn putCurrentCursor(self: *const Display, arena: std.mem.Allocator, buf: *std.ArrayList(u8)) !void {
    if (self.buffer_view.viewCursor()) |cursor| {
        try self.putCursor(arena, buf, cursor.x, cursor.y);
    }
    if (self.command_buffer_view.viewCursor()) |cursor| {
        try self.putCursor(arena, buf, cursor.x, self.size.rows - 1);
    }
}

fn clearScreen(_: *const Display, _: std.mem.Allocator, buf: *std.ArrayList(u8)) !void {
    try buf.appendSlice("\x1b[2J");
    try buf.appendSlice("\x1b[H");
}

fn drawRows(self: *const Display, buf: *std.ArrayList(u8)) !void {
    for (0..self.buffer_view.height) |y| {
        if (y > 0) try buf.appendSlice("\r\n");
        try buf.appendSlice("\x1b[K");
        try buf.appendSlice(self.buffer_view.viewRow(y));
    }
    try buf.appendSlice("\r\n");
}
