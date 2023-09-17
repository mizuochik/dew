const std = @import("std");
const fs = std.fs;
const fmt = std.fmt;
const Allocator = std.mem.Allocator;

const dew = @import("../../dew.zig");
const view = dew.view;
const Key = dew.models.Key;
const models = dew.models;
const Publisher = dew.event.Publisher;
const Subscriber = dew.event.Subscriber;
const Arrow = dew.models.Arrow;
const Buffer = dew.models.Buffer;
const UnicodeString = dew.models.UnicodeString;

buffer_view: *dew.view.BufferView,
status_message: *models.StatusMessage,
file_path: ?[]const u8 = null,
model_event_publisher: *const Publisher(dew.models.Event),
buffer_selector: *models.BufferSelector,
allocator: Allocator,

const EditorController = @This();

pub fn init(allocator: Allocator, buffer_view: *view.BufferView, status_message: *models.StatusMessage, buffer_selector: *models.BufferSelector, model_event_publisher: *const Publisher(models.Event)) !EditorController {
    return EditorController{
        .allocator = allocator,
        .buffer_view = buffer_view,
        .status_message = status_message,
        .buffer_selector = buffer_selector,
        .model_event_publisher = model_event_publisher,
    };
}

pub fn deinit(_: *const EditorController) void {}

pub fn processKeypress(self: *EditorController, key: Key) !void {
    switch (key) {
        .del => try self.deleteBackwardChar(),
        .ctrl => |k| switch (k) {
            'Q' => return error.Quit,
            'S' => try self.saveFile(),
            'K' => try self.killLine(),
            'D' => try self.deleteChar(),
            'H' => try self.deleteBackwardChar(),
            'M' => try self.breakLine(),
            'P' => try self.moveCursor(.up),
            'N' => try self.moveCursor(.down),
            'F' => try self.moveCursor(.right),
            'B' => try self.moveCursor(.left),
            'J' => try self.buffer_selector.current_buffer.joinLine(),
            'A' => {
                try self.buffer_selector.current_buffer.moveToBeginningOfLine();
                self.buffer_view.updateLastCursorX();
            },
            'E' => {
                try self.buffer_selector.current_buffer.moveToEndOfLine();
                self.buffer_view.updateLastCursorX();
            },
            'V' => {
                self.buffer_view.scrollDown(self.buffer_view.height * 15 / 16);
                const cur = self.buffer_view.getNormalizedCursor();
                try self.buffer_selector.current_buffer.setCursor(cur.x, cur.y);
            },
            else => {},
        },
        .meta => |k| switch (k) {
            'v' => {
                self.buffer_view.scrollUp(self.buffer_view.height * 15 / 16);
                const cur = self.buffer_view.getNormalizedCursor();
                try self.buffer_selector.current_buffer.setCursor(cur.x, cur.y);
            },
            else => {},
        },
        .plain => |k| try self.insertChar(k),
        .arrow => |k| try self.moveCursor(k),
    }
}

fn moveCursor(self: *EditorController, k: Arrow) !void {
    switch (k) {
        .up => {
            const y = self.buffer_view.getCursor().y;
            if (y > 0) {
                const new_cursor = self.buffer_view.getBufferPopsition(.{ .x = self.buffer_view.last_cursor_x, .y = y - 1 });
                try self.buffer_selector.current_buffer.setCursor(new_cursor.x, new_cursor.y);
            }
        },
        .down => {
            const y = self.buffer_view.getCursor().y;
            if (y < self.buffer_view.getNumberOfLines() - 1) {
                const new_cursor = self.buffer_view.getBufferPopsition(.{ .x = self.buffer_view.last_cursor_x, .y = y + 1 });
                try self.buffer_selector.current_buffer.setCursor(new_cursor.x, new_cursor.y);
            }
        },
        .left => {
            try self.buffer_selector.current_buffer.moveBackward();
            self.buffer_view.updateLastCursorX();
        },
        .right => {
            try self.buffer_selector.current_buffer.moveForward();
            self.buffer_view.updateLastCursorX();
        },
    }
    self.buffer_view.normalizeScroll();
}

fn deleteChar(self: *EditorController) !void {
    try self.buffer_selector.current_buffer.deleteChar();
    self.buffer_view.updateLastCursorX();
}

fn deleteBackwardChar(self: *EditorController) !void {
    try self.buffer_selector.current_buffer.deleteBackwardChar();
    self.buffer_view.updateLastCursorX();
}

fn breakLine(self: *EditorController) !void {
    try self.buffer_selector.current_buffer.breakLine();
    self.buffer_view.updateLastCursorX();
}

fn killLine(self: *EditorController) !void {
    try self.buffer_selector.current_buffer.killLine();
    self.buffer_view.updateLastCursorX();
}

fn insertChar(self: *EditorController, char: u21) !void {
    try self.buffer_selector.current_buffer.insertChar(char);
    self.buffer_view.updateLastCursorX();
}

pub fn openFile(self: *EditorController, path: []const u8) !void {
    var f = try fs.cwd().openFile(path, .{});
    var reader = f.reader();

    var new_rows = std.ArrayList(UnicodeString).init(self.allocator);
    errdefer {
        for (new_rows.items) |row| row.deinit();
        new_rows.deinit();
    }

    while (true) {
        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();
        reader.streamUntilDelimiter(buf.writer(), '\n', null) catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };
        var new_row = try UnicodeString.init(self.allocator);
        errdefer new_row.deinit();
        try new_row.appendSlice(buf.items);
        try new_rows.append(new_row);
    }

    var last_row = try UnicodeString.init(self.allocator);
    errdefer last_row.deinit();
    try new_rows.append(last_row);

    for (self.buffer_selector.current_buffer.rows.items) |row| row.deinit();
    self.buffer_selector.current_buffer.rows.deinit();
    self.buffer_selector.current_buffer.rows = new_rows;
    try self.buffer_selector.current_buffer.notifyUpdate();

    self.file_path = path;

    const new_message = try fmt.allocPrint(self.allocator, "{s}", .{path});
    errdefer self.allocator.free(new_message);
    try self.status_message.setMessage(new_message);
}

fn saveFile(self: *EditorController) !void {
    var f = try fs.cwd().createFile(self.file_path.?, .{});
    defer f.close();
    for (self.buffer_selector.current_buffer.rows.items, 0..) |row, i| {
        if (i > 0)
            _ = try f.write("\n");
        _ = try f.write(row.buffer.items);
    }
    const new_status = try fmt.allocPrint(self.allocator, "Saved: {s}", .{self.file_path.?});
    errdefer self.allocator.free(new_status);
    try self.status_message.setMessage(new_status);
}
