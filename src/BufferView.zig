const std = @import("std");
const models = @import("models.zig");
const view = @import("view.zig");
const Text = @import("Text.zig");
const BufferSelector = @import("BufferSelector.zig");
const Position = @import("Position.zig");
const Editor = @import("Editor.zig");
const Client = @import("Client.zig");

const BufferView = @This();

const RowSlice = struct {
    buf_y: usize,
    buf_x_start: usize,
    buf_x_end: usize,
};

const empty: []const u8 = b: {
    const s: [0]u8 = undefined;
    break :b &s;
};

rows: std.ArrayList(RowSlice),
width: usize,
height: usize,
is_active: bool,
last_cursor_x: usize = 0,
mode: Text.Mode,
editor: *Editor,
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator, editor: *Editor, mode: Text.Mode) BufferView {
    const rows = std.ArrayList(RowSlice).init(allocator);
    errdefer rows.deinit();
    return .{
        .rows = rows,
        .width = 0,
        .height = 0,
        .is_active = mode != Text.Mode.command,
        .mode = mode,
        .editor = editor,
        .allocator = allocator,
    };
}

pub fn deinit(self: *const BufferView) void {
    self.rows.deinit();
}

pub fn viewCursor(self: *const BufferView, edit: *Client.Edit) ?Position {
    if (!self.is_active) {
        return null;
    }
    const cursor = self.getCursor(edit);
    const y_offset = if (cursor.y >= edit.text.y_scroll) cursor.y - edit.text.y_scroll else return null;
    if (y_offset >= self.height) {
        return null;
    }
    return .{
        .x = cursor.x,
        .y = y_offset,
    };
}

pub fn getCursor(self: *const BufferView, edit: *Client.Edit) Position {
    const cursor = switch (self.mode) {
        .command => self.editor.client.command_line_edit.cursor,
        else => self.editor.client.getActiveFile().?.cursor,
    };
    const c_y = cursor.y;
    const c_x = cursor.x;
    if (self.rows.items.len <= 0) {
        return .{
            .x = 0,
            .y = 0,
        };
    }
    var j: usize = self.rows.items.len;
    const y = while (j > 0) : (j -= 1) {
        const row = self.rows.items[j - 1];
        if (row.buf_y == c_y and row.buf_x_start <= c_x and c_x <= row.buf_x_end)
            break j - 1;
    } else 0;
    const row_slice = self.rows.items[y];
    const x = for (row_slice.buf_x_start..row_slice.buf_x_end + 1) |i| {
        if (i == c_x) {
            const buf_row = edit.text.rows.items[row_slice.buf_y];
            break buf_row.width_index.items[i] - buf_row.width_index.items[row_slice.buf_x_start];
        }
    } else 0;
    return .{
        .x = x,
        .y = y,
    };
}

pub fn getNumberOfLines(self: *const BufferView) usize {
    return self.rows.items.len;
}

pub fn getBufferPosition(self: *const BufferView, edit: *Client.Edit, view_position: Position) Position {
    const row_slice = self.rows.items[view_position.y];
    const buffer_row = edit.text.rows.items[row_slice.buf_y];
    const start_width = buffer_row.width_index.items[row_slice.buf_x_start];
    const buf_x = for (row_slice.buf_x_start..row_slice.buf_x_end) |bx| {
        const view_x_left = buffer_row.width_index.items[bx] - start_width;
        const view_x_right = buffer_row.width_index.items[bx + 1] - start_width;
        if (view_x_left <= view_position.x and view_position.x + 1 <= view_x_right) {
            break bx;
        }
    } else row_slice.buf_x_end;
    return .{
        .x = buf_x,
        .y = row_slice.buf_y,
    };
}

pub fn getNormalizedCursor(self: *BufferView, edit: *Client.Edit) Position {
    const upper_limit = edit.text.y_scroll;
    const bottom_limit = edit.text.y_scroll + self.height;
    const cursor = self.getCursor(edit);
    if (cursor.y < upper_limit) {
        return .{ .x = cursor.x, .y = upper_limit };
    }
    if (cursor.y >= bottom_limit) {
        return .{ .x = cursor.x, .y = bottom_limit - 1 };
    }
    return cursor;
}

pub fn updateLastCursorX(self: *BufferView, edit: *Client.Edit) void {
    self.last_cursor_x = self.getCursor(edit).x;
}

pub fn setSize(self: *BufferView, width: usize, height: usize) !void {
    self.width = width;
    self.height = height;
}

pub fn scrollUp(_: *BufferView, edit: *Client.Edit, diff: usize) void {
    if (edit.text.y_scroll < diff)
        edit.text.y_scroll = 0
    else
        edit.text.y_scroll -= diff;
}

pub fn scrollDown(self: *BufferView, edit: *Client.Edit, diff: usize) void {
    const max_scroll = if (self.rows.items.len > self.height) self.rows.items.len - self.height else 0;
    if (edit.text.y_scroll + diff > max_scroll)
        edit.text.y_scroll = max_scroll
    else
        edit.text.y_scroll += diff;
}

pub fn render(self: *BufferView, text: *Text, buffer: [][]u8) !void {
    var new_rows = std.ArrayList(RowSlice).init(self.allocator);
    errdefer new_rows.deinit();
    const buffer_width = buffer[0].len;
    for (text.rows.items, 0..) |row, y| {
        var x_start: usize = 0;
        for (0..row.getLen()) |x| {
            if (row.width_index.items[x + 1] - row.width_index.items[x_start] > buffer_width) {
                try new_rows.append(.{
                    .buf_y = y,
                    .buf_x_start = x_start,
                    .buf_x_end = x,
                });
                x_start = x;
            }
        }
        if (row.getLen() <= 0 or x_start < row.getLen()) {
            try new_rows.append(RowSlice{
                .buf_y = y,
                .buf_x_start = x_start,
                .buf_x_end = row.getLen(),
            });
        }
    }
    const draw_height = if (buffer.len < new_rows.items.len - text.y_scroll) buffer.len else new_rows.items.len - text.y_scroll;
    for (0..draw_height) |i| {
        const row_slice = new_rows.items[i + text.y_scroll];
        std.mem.copy(u8, buffer[i], text.rows.items[row_slice.buf_y].sliceAsRaw(row_slice.buf_x_start, row_slice.buf_x_end));
    }
    self.rows.deinit();
    self.rows = new_rows;
}
