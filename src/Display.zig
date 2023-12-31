const std = @import("std");
const builtin = @import("builtin");
const view = @import("view.zig");
const event = @import("event.zig");
const BufferView = @import("BufferView.zig");
const StatusBarView = @import("StatusBarView.zig");
const DisplaySize = @import("DisplaySize.zig");
const Terminal = @import("Terminal.zig");

buffer: [][]u8,
file_buffer_view: *BufferView,
status_bar_view: *StatusBarView,
command_buffer_view: *BufferView,
allocator: std.mem.Allocator,
size: *DisplaySize,

const Display = @This();

pub const Area = struct {
    rows: [][]u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, width: usize, height: usize) !Area {
        var rows = try allocator.alloc([]u8, height);
        errdefer allocator.free(rows);
        var i: usize = 0;
        errdefer for (0..i) |j| {
            allocator.free(rows[j]);
        };
        while (i < height) : (i += 1) {
            rows[i] = try allocator.alloc(u8, width);
        }
        return .{
            .rows = rows,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *const Area) void {
        for (0..self.rows.len) |i| {
            self.allocator.free(self.rows[i]);
        }
        self.allocator.free(self.rows);
    }
};

pub fn init(allocator: std.mem.Allocator, file_buffer_view: *BufferView, status_bar_view: *StatusBarView, command_buffer_view: *BufferView, size: *DisplaySize) !Display {
    const buffer = try initBuffer(allocator, size);
    errdefer {
        for (0..buffer.len) |i| allocator.free(buffer[i]);
        allocator.free(buffer);
    }
    return .{
        .buffer = buffer,
        .file_buffer_view = file_buffer_view,
        .status_bar_view = status_bar_view,
        .command_buffer_view = command_buffer_view,
        .allocator = allocator,
        .size = size,
    };
}

pub fn deinit(self: *const Display) void {
    for (self.buffer) |row| {
        self.allocator.free(row);
    }
    self.allocator.free(self.buffer);
}

pub fn eventSubscriber(self: *Display) event.Subscriber(view.Event) {
    return .{
        .ptr = self,
        .vtable = &.{
            .handle = handleEvent,
        },
    };
}

pub fn getArea(self: *const Display, top: usize, bottom: usize, left: usize, right: usize) !Area {
    var area = try Area.init(self.allocator, right - left, bottom - top);
    errdefer area.deinit();
    for (0..(bottom - top)) |i| {
        std.mem.copy(u8, area.rows[i], self.buffer[top + i][left..right]);
    }
    return area;
}

pub fn changeSize(self: *Display, size: *const Terminal.WindowSize) !void {
    self.size.cols = @intCast(size.cols);
    self.size.rows = @intCast(size.rows);
    const new_buffer = try initBuffer(self.allocator, self.size);
    errdefer {
        for (0..new_buffer.len) |i| self.allocator.free(new_buffer[i]);
        self.allocator.free(new_buffer);
    }
    for (0..self.buffer.len) |i| self.allocator.free(self.buffer[i]);
    self.allocator.free(self.buffer);

    self.buffer = new_buffer;

    try self.file_buffer_view.setSize(self.size.cols, self.size.rows - 1);
    try self.command_buffer_view.setSize(self.size.cols, 1);
    try self.status_bar_view.setSize(self.size.cols);
}

pub fn render(self: *Display) !void {
    try self.synchronizeBufferView();
    var bottom_line = self.buffer[self.buffer.len - 1];
    for (0..bottom_line.len) |i| {
        bottom_line[i] = ' ';
    }
    self.command_buffer_view.render(bottom_line);
    var rest: usize = 0;
    var i = @as(i32, @intCast(bottom_line.len)) - 1;
    while (i >= 0 and bottom_line[@intCast(i)] == ' ') : (i -= 1) {
        rest += 1;
    }
    self.status_bar_view.render(bottom_line[bottom_line.len - rest ..]);
    try self.writeUpdates();
}

fn initBuffer(allocator: std.mem.Allocator, display_size: *DisplaySize) ![][]u8 {
    var new_buffer = try allocator.alloc([]u8, display_size.rows);
    var i: usize = 0;
    errdefer {
        for (0..i) |j| {
            allocator.free(new_buffer[j]);
        }
        allocator.free(new_buffer);
    }
    while (i < display_size.rows) : (i += 1) {
        new_buffer[i] = try allocator.alloc(u8, display_size.cols);
        for (0..display_size.cols) |j| {
            new_buffer[i][j] = ' ';
        }
    }
    return new_buffer;
}

fn handleEvent(ctx: *anyopaque, event_: view.Event) anyerror!void {
    const self: *Display = @ptrCast(@alignCast(ctx));
    switch (event_) {
        .buffer_view_updated => {
            try self.synchronizeBufferView();
            try self.writeUpdates();
        },
        .command_buffer_view_updated, .status_bar_view_updated => {
            try self.updateBottomLine();
            try self.writeUpdates();
        },
        .screen_size_changed => {
            const new_buffer = try initBuffer(self.allocator, self.size);
            errdefer {
                for (0..new_buffer.len) |i| self.allocator.free(new_buffer[i]);
                self.allocator.free(new_buffer);
            }
            for (0..self.buffer.len) |i| self.allocator.free(self.buffer[i]);
            self.allocator.free(self.buffer);

            self.buffer = new_buffer;

            try self.file_buffer_view.setSize(self.size.cols, self.size.rows - 1);
            try self.command_buffer_view.setSize(self.size.cols, 1);
            try self.status_bar_view.setSize(self.size.cols);
        },
    }
}

fn writeUpdates(self: *const Display) !void {
    if (builtin.is_test) {
        return;
    }
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var tmp = std.ArrayList(u8).init(self.allocator);
    defer tmp.deinit();
    try self.hideCursor(&tmp);
    try self.putCursor(arena.allocator(), &tmp, 0, 0);
    for (0..self.size.rows) |y| {
        if (y > 0) try tmp.appendSlice("\r\n");
        try tmp.appendSlice("\x1b[K");
        try tmp.appendSlice(self.buffer[y]);
    }
    try self.putCurrentCursor(arena.allocator(), &tmp);
    try self.showCursor(&tmp);
    try std.io.getStdOut().writeAll(tmp.items);
}

fn synchronizeBufferView(self: *Display) !void {
    for (0..self.file_buffer_view.height) |i| {
        const row = self.file_buffer_view.viewRow(i);
        for (0..self.size.cols) |j| {
            self.buffer[i][j] = if (j < row.len) row[j] else ' ';
        }
    }
}

fn updateBottomLine(self: *Display) !void {
    const status_bar = try self.status_bar_view.viewContent();
    const command_buffer = self.command_buffer_view.viewRow(0);
    const bottom = self.size.rows - 1;
    for (0..command_buffer.len) |x| {
        self.buffer[bottom][x] = command_buffer[x];
    }
    if (self.size.cols >= command_buffer.len + status_bar.len) {
        const space = self.size.cols - (command_buffer.len + status_bar.len);
        for (0..space) |i| {
            self.buffer[bottom][command_buffer.len + i] = ' ';
        }
        for (0..status_bar.len) |i| {
            self.buffer[bottom][command_buffer.len + space + i] = status_bar[i];
        }
    } else {
        const overlap = command_buffer.len + status_bar.len - self.size.cols;
        for (0..status_bar.len - overlap) |i| {
            self.buffer[bottom][command_buffer.len + i] = status_bar[i - overlap];
        }
    }
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
    if (self.file_buffer_view.viewCursor()) |cursor| {
        try self.putCursor(arena, buf, cursor.x, cursor.y);
    }
    if (self.command_buffer_view.viewCursor()) |cursor| {
        try self.putCursor(arena, buf, cursor.x, self.size.rows - 1);
    }
}
