const std = @import("std");
const dew = @import("../dew.zig");

display_buffer: [][]u8,
buffer_view: *const dew.view.BufferView,
status_bar_view: *const dew.view.StatusBarView,
command_buffer_view: *const dew.view.BufferView,
allocator: std.mem.Allocator,
size: dew.Editor.WindowSize,

const Display = @This();

pub fn init(allocator: std.mem.Allocator, buffer_view: *const dew.view.BufferView, status_bar_view: *const dew.view.StatusBarView, command_buffer_view: *const dew.view.BufferView, size: dew.Editor.WindowSize) !Display {
    var display_buffer_al = std.ArrayList([]u8).init(allocator);
    errdefer {
        for (display_buffer_al.items) |row| {
            allocator.free(row);
        }
        display_buffer_al.deinit();
    }
    var y: usize = 0;
    while (y < size.rows) : (y += 1) {
        const row_buffer = try allocator.alloc(u8, size.cols);
        errdefer allocator.free(row_buffer);
        try display_buffer_al.append(row_buffer);
    }
    const display_buffer = try display_buffer_al.toOwnedSlice();
    errdefer allocator.free(display_buffer);
    return .{
        .display_buffer = display_buffer,
        .buffer_view = buffer_view,
        .status_bar_view = status_bar_view,
        .command_buffer_view = command_buffer_view,
        .allocator = allocator,
        .size = size,
    };
}

pub fn deinit(self: *const Display) void {
    for (self.display_buffer) |row| {
        self.allocator.free(row);
    }
    self.allocator.free(self.display_buffer);
}

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
            try self.synchronizeBufferView();
            try self.writeUpdates();
        },
        .command_buffer_view_updated, .status_bar_view_updated => {
            try self.updateBottomLine();
            try self.writeUpdates();
        },
    }
}

fn writeUpdates(self: *const Display) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var tmp = std.ArrayList(u8).init(self.allocator);
    defer tmp.deinit();
    try self.hideCursor(&tmp);
    try self.putCursor(arena.allocator(), &tmp, 0, 0);
    for (0..self.size.rows) |y| {
        if (y > 0) try tmp.appendSlice("\r\n");
        try tmp.appendSlice("\x1b[K");
        try tmp.appendSlice(self.display_buffer[y]);
    }
    try self.putCurrentCursor(arena.allocator(), &tmp);
    try self.showCursor(&tmp);
    try std.io.getStdOut().writeAll(tmp.items);
}

fn synchronizeBufferView(self: *Display) !void {
    for (0..self.buffer_view.height) |i| {
        const row = self.buffer_view.viewRow(i);
        for (0..self.size.cols) |j| {
            self.display_buffer[i][j] = if (j < row.len) row[j] else ' ';
        }
    }
}

fn updateBottomLine(self: *Display) !void {
    const status_bar = try self.status_bar_view.view();
    const command_buffer = self.command_buffer_view.viewRow(0);
    const bottom = self.size.rows - 1;
    for (0..command_buffer.len) |x| {
        self.display_buffer[bottom][x] = command_buffer[x];
    }
    if (self.size.cols >= command_buffer.len + status_bar.len) {
        const space = self.size.cols - (command_buffer.len + status_bar.len);
        for (0..space) |i| {
            self.display_buffer[bottom][command_buffer.len + i] = ' ';
        }
        for (0..status_bar.len) |i| {
            self.display_buffer[bottom][command_buffer.len + space + i] = status_bar[i];
        }
    } else {
        const overlap = command_buffer.len + status_bar.len - self.size.cols;
        for (0..status_bar.len - overlap) |i| {
            self.display_buffer[bottom][command_buffer.len + i] = status_bar[i - overlap];
        }
    }
}

fn synchronizeScreen(self: *const Display, arena: std.mem.Allocator, buf: *std.ArrayList(u8)) !void {
    try self.hideCursor(buf);
    try self.putCursor(arena, buf, 0, 0);

    for (0..self.size.rows - 1) |y| {
        if (y > 0) try buf.appendSlice("\r\n");
        try buf.appendSlice("\x1b[K");
        try buf.appendSlice(self.display_buffer[y]);
    }
    try buf.appendSlice("\r\n");

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
