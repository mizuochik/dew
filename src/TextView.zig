const TextView = @This();
const std = @import("std");
const Text = @import("Text.zig");
const BufferSelector = @import("BufferSelector.zig");
const Position = @import("Position.zig");
const Editor = @import("Editor.zig");
const Client = @import("Client.zig");
const Display = @import("Display.zig");
const TextRef = @import("TextRef.zig");

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
mode: Text.Mode,
editor: *Editor,
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator, editor: *Editor, mode: Text.Mode) TextView {
    const rows = std.ArrayList(RowSlice).init(allocator);
    errdefer rows.deinit();
    return .{
        .rows = rows,
        .width = 0,
        .height = 0,
        .mode = mode,
        .editor = editor,
        .allocator = allocator,
    };
}

pub fn deinit(self: *const TextView) void {
    self.rows.deinit();
}

pub fn isActive(self: *const TextView, edit: *TextRef) bool {
    const active_ref = self.editor.client.getActiveEdit() orelse return false;
    return edit == active_ref;
}

pub fn viewSelection(self: *const TextView, edit: *TextRef) ?Position {
    if (!self.isActive(edit)) {
        return null;
    }
    const selection = self.getSelection(edit);
    const y_offset = if (selection.line >= edit.y_scroll) selection.line - edit.y_scroll else return null;
    if (y_offset >= self.height) {
        return null;
    }
    return .{
        .character = selection.character,
        .line = y_offset,
    };
}

pub fn getSelection(self: *const TextView, edit: *TextRef) Position {
    const selection = switch (self.mode) {
        .command => self.editor.client.command_line_ref.selection,
        else => self.editor.client.getActiveFile().?.selection,
    };
    const c_y = selection.y;
    const c_x = selection.x;
    if (self.rows.items.len <= 0) {
        return .{
            .character = 0,
            .line = 0,
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
        .character = x,
        .line = y,
    };
}

pub fn getNumberOfLines(self: *const TextView) usize {
    return self.rows.items.len;
}

pub fn getBufferPosition(self: *const TextView, edit: *TextRef, view_position: Position) Position {
    const row_slice = self.rows.items[view_position.line];
    const buffer_row = edit.text.rows.items[row_slice.buf_y];
    const start_width = buffer_row.width_index.items[row_slice.buf_x_start];
    const buf_x = for (row_slice.buf_x_start..row_slice.buf_x_end) |bx| {
        const view_x_left = buffer_row.width_index.items[bx] - start_width;
        const view_x_right = buffer_row.width_index.items[bx + 1] - start_width;
        if (view_x_left <= view_position.character and view_position.character + 1 <= view_x_right) {
            break bx;
        }
    } else row_slice.buf_x_end;
    return .{
        .character = buf_x,
        .line = row_slice.buf_y,
    };
}

pub fn getNormalizedSelection(self: *TextView, edit: *TextRef) Position {
    const upper_limit = edit.y_scroll;
    const bottom_limit = edit.y_scroll + self.height;
    const selection = self.getSelection(edit);
    if (selection.line < upper_limit) {
        return .{ .character = selection.character, .line = upper_limit };
    }
    if (selection.line >= bottom_limit) {
        return .{ .character = selection.character, .line = bottom_limit - 1 };
    }
    return selection;
}

pub fn updateLastSelectionX(self: *TextView, edit: *TextRef) void {
    edit.selection.last_view_x = self.getSelection(edit).character;
}

pub fn setSize(self: *TextView, width: usize, height: usize) !void {
    self.width = width;
    self.height = height;
}

pub fn scrollUp(_: *TextView, edit: *TextRef, diff: usize) void {
    if (edit.y_scroll < diff)
        edit.y_scroll = 0
    else
        edit.y_scroll -= diff;
}

pub fn scrollDown(self: *TextView, edit: *TextRef, diff: usize) void {
    const max_scroll = if (self.rows.items.len > self.height) self.rows.items.len - self.height else 0;
    if (edit.y_scroll + diff > max_scroll)
        edit.y_scroll = max_scroll
    else
        edit.y_scroll += diff;
}

pub fn render(self: *TextView, buffer: *Display.Buffer, edit: *TextRef) !void {
    var new_rows = std.ArrayList(RowSlice).init(self.allocator);
    errdefer new_rows.deinit();
    for (edit.text.rows.items, 0..) |row, y| {
        var x_start: usize = 0;
        for (0..row.getLen()) |x| {
            if (row.width_index.items[x + 1] - row.width_index.items[x_start] > buffer.width) {
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
    const cells, const draw_height = switch (self.mode) {
        .file => .{
            buffer.cells,
            @min(buffer.height - 1, new_rows.items.len - edit.y_scroll),
        },
        .command => .{
            buffer.cells[buffer.width * (buffer.height - 1) ..],
            1,
        },
    };
    for (0..draw_height) |l| {
        const row_slice = new_rows.items[l + edit.y_scroll];
        const row_utf8 = try edit.text.rows.items[row_slice.buf_y].utf8View(row_slice.buf_x_start, row_slice.buf_x_end);
        var row_utf8_it = row_utf8.iterator();
        var c: usize = 0;
        while (row_utf8_it.nextCodepoint()) |cp| {
            var buf: [3]u8 = undefined;
            const size = try std.unicode.utf8Encode(cp, &buf);
            _ = size;
            cells[l * buffer.width + c] = .{
                .character = cp,
                .foreground = .default,
                .background = .default,
            };
            c += 1;
            if (cp > std.math.maxInt(u8)) {
                cells[l * buffer.width + c] = null;
                c += 1;
            }
        }
    }
    self.rows.deinit();
    self.rows = new_rows;
    if (self.viewSelection(edit)) |selection| {
        if (cells[selection.line * buffer.width + selection.character]) |*cell| {
            cell.background = .gray;
        }
    }
}
