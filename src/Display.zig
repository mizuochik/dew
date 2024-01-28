const std = @import("std");
const builtin = @import("builtin");
const EditView = @import("EditView.zig");
const StatusView = @import("StatusView.zig");
const DisplaySize = @import("DisplaySize.zig");
const Client = @import("Client.zig");
const Terminal = @import("Terminal.zig");

pub const Color = enum {
    default,
    gray,
};

pub const Cell = struct {
    character: u21,
    foreground: Color,
    background: Color,
};

pub const Buffer = struct {
    allocator: std.mem.Allocator,
    width: usize,
    height: usize,
    cells: []?Cell,

    pub fn init(allocator: std.mem.Allocator, width: usize, height: usize) !@This() {
        const cells = try allocator.alloc(?Cell, width * height);
        errdefer allocator.free(cells);
        var buffer = @This(){
            .allocator = allocator,
            .width = width,
            .height = height,
            .cells = cells,
        };
        buffer.clear();
        return buffer;
    }

    pub fn clear(self: *@This()) void {
        for (self.cells) |*cell| {
            cell.* = .{
                .character = ' ',
                .foreground = .default,
                .background = .default,
            };
        }
    }

    pub fn deinit(self: *const @This()) void {
        self.allocator.free(self.cells);
    }

    pub fn view(self: *const @This(), top: usize, bottom: usize, left: usize, right: usize) !@This() {
        const view_width = right - left;
        const view_height = bottom - top;
        const view_buffer = try @This().init(self.allocator, view_width, view_height);
        errdefer view_buffer.deinit();
        for (0..view_height) |i| {
            for (0..view_width) |j| {
                view_buffer.cells[i * view_width + j] = self.cells[(top + i) * self.width + left + j];
            }
        }
        return view_buffer;
    }

    pub fn rowSlice(self: *const @This(), y: usize) ![]const u8 {
        var s = std.ArrayList(u8).init(self.allocator);
        errdefer s.deinit();
        var buf: [4]u8 = undefined;
        for (0..self.width) |x| {
            const cell = self.cells[y * self.width + x] orelse continue;
            const n = try std.unicode.utf8Encode(cell.character, &buf);
            try s.appendSlice(buf[0..n]);
        }
        return s.toOwnedSlice();
    }

    pub fn expectEqualSlice(self: *const @This(), expected: []const u8) !void {
        var expected_it = (try std.unicode.Utf8View.init(expected)).iterator();
        var expected_row_st: usize = 0;
        var y: usize = 0;
        while (expected_it.i < expected.len) {
            while (expected_it.nextCodepoint()) |cp| {
                if (cp == '\n') {
                    break;
                }
            }
            const expected_row = std.mem.trimRight(u8, expected[expected_row_st..expected_it.i], " \n");
            const actual_row = try self.rowSlice(y);
            defer self.allocator.free(actual_row);
            try std.testing.expectEqualStrings(expected_row, std.mem.trimRight(u8, actual_row, " "));
            expected_row_st = expected_it.i;
            y += 1;
        }
    }
};

buffer: Buffer,
file_edit_view: *EditView,
status_view: *StatusView,
command_edit_view: *EditView,
allocator: std.mem.Allocator,
client: *Client,
size: *DisplaySize,

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

pub fn init(allocator: std.mem.Allocator, file_edit_view: *EditView, status_view: *StatusView, command_edit_view: *EditView, client: *Client, size: *DisplaySize) !@This() {
    const buffer = try Buffer.init(allocator, size.cols, size.rows);
    errdefer buffer.deinit();
    return .{
        .buffer = buffer,
        .file_edit_view = file_edit_view,
        .status_view = status_view,
        .command_edit_view = command_edit_view,
        .allocator = allocator,
        .client = client,
        .size = size,
    };
}

pub fn deinit(self: *const @This()) void {
    self.buffer.deinit();
}

pub fn getArea(self: *const @This(), top: usize, bottom: usize, left: usize, right: usize) !Buffer {
    return self.buffer.view(top, bottom, left, right);
}

pub fn changeSize(self: *@This(), size: *const Terminal.WindowSize) !void {
    self.size.cols = @intCast(size.cols);
    self.size.rows = @intCast(size.rows);

    try self.file_edit_view.setSize(self.size.cols, self.size.rows - 1);

    const new_buffer = try Buffer.init(self.allocator, size.cols, size.rows);
    errdefer new_buffer.deinit();
    self.buffer.deinit();
    self.buffer = new_buffer;

    try self.command_edit_view.setSize(self.size.cols, 1);
    try self.status_view.setSize(self.size.cols);
}

pub fn render(self: *@This()) !void {
    self.buffer.clear();
    try self.file_edit_view.render(&self.buffer, self.client.getActiveFile().?);
    try self.command_edit_view.render(&self.buffer, &self.client.command_line_edit);
    try self.status_view.render(&self.buffer, &self.client.status);
    try self.drawBuffer();
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

fn drawBuffer(self: *const @This()) !void {
    if (builtin.is_test) {
        return;
    }
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var tmp = std.ArrayList(u8).init(self.allocator);
    defer tmp.deinit();
    try self.moveTerminalCursor(arena.allocator(), &tmp, 0, 0);
    var last_background = Color.default;
    for (0..self.buffer.height) |y| {
        if (y > 0) try tmp.appendSlice("\r\n");
        for (0..self.buffer.width) |x| {
            if (self.buffer.cells[y * self.buffer.width + x]) |cell| {
                if (cell.background != last_background) {
                    try tmp.appendSlice(switch (cell.background) {
                        .gray => "\x1b[47m",
                        .default => "\x1b[0m",
                    });
                    last_background = cell.background;
                }
                var character: [3]u8 = undefined;
                const size = try std.unicode.utf8Encode(cell.character, &character);
                try tmp.appendSlice(character[0..size]);
            }
        }
    }
    try std.io.getStdOut().writeAll(tmp.items);
}

pub fn initTerminalCursor(_: *const @This()) !void {
    // Hide terminal cursor
    _ = try std.io.getStdOut().write("\x1b[?25l");
}

pub fn deinitTerminalCursor(_: *const @This()) void {
    // Show terminal cursor
    _ = std.io.getStdOut().write("\x1b[?25h") catch unreachable;
}

fn moveTerminalCursor(_: *const @This(), arena: std.mem.Allocator, buf: *std.ArrayList(u8), x: usize, y: usize) !void {
    try buf.appendSlice(try std.fmt.allocPrint(arena, "\x1b[{d};{d}H", .{ y + 1, x + 1 }));
}
