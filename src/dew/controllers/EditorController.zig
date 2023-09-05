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

buffer: *dew.models.Buffer,
buffer_view: *dew.view.BufferView,
command_buffer: *dew.models.Buffer,
last_view_x: usize = 0,
status_message: *models.StatusMessage,
file_path: ?[]const u8 = null,
model_event_publisher: *const Publisher(dew.models.Event),
allocator: Allocator,

const EditorController = @This();

pub fn init(allocator: Allocator, buffer: *models.Buffer, buffer_view: *view.BufferView, command_buffer: *models.Buffer, status_message: *models.StatusMessage, model_event_publisher: *const Publisher(models.Event)) !EditorController {
    return EditorController{
        .allocator = allocator,
        .buffer = buffer,
        .buffer_view = buffer_view,
        .command_buffer = command_buffer,
        .status_message = status_message,
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
            'J' => try self.buffer.joinLine(),
            'A' => {
                try self.buffer.moveToBeginningOfLine();
                self.updateLastViewX();
            },
            'E' => {
                try self.buffer.moveToEndOfLine();
                self.updateLastViewX();
            },
            'V' => {
                self.buffer_view.scrollDown(self.buffer_view.height * 15 / 16);
                const cur = self.buffer_view.getNormalizedCursor();
                try self.buffer.setCursor(cur.x, cur.y);
            },
            else => {},
        },
        .meta => |k| switch (k) {
            'v' => {
                self.buffer_view.scrollUp(self.buffer_view.height * 15 / 16);
                const cur = self.buffer_view.getNormalizedCursor();
                try self.buffer.setCursor(cur.x, cur.y);
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
                const new_cursor = self.buffer_view.getBufferPopsition(.{ .x = self.last_view_x, .y = y - 1 });
                try self.buffer.setCursor(new_cursor.x, new_cursor.y);
            }
        },
        .down => {
            const y = self.buffer_view.getCursor().y;
            if (y < self.buffer_view.getNumberOfLines() - 1) {
                const new_cursor = self.buffer_view.getBufferPopsition(.{ .x = self.last_view_x, .y = y + 1 });
                try self.buffer.setCursor(new_cursor.x, new_cursor.y);
            }
        },
        .left => {
            try self.buffer.moveBackward();
            self.updateLastViewX();
        },
        .right => {
            try self.buffer.moveForward();
            self.updateLastViewX();
        },
    }
    self.buffer_view.normalizeScroll();
}

fn deleteChar(self: *EditorController) !void {
    try self.buffer.deleteChar();
    self.updateLastViewX();
}

fn deleteBackwardChar(self: *EditorController) !void {
    try self.buffer.deleteBackwardChar();
    self.updateLastViewX();
}

fn breakLine(self: *EditorController) !void {
    try self.buffer.breakLine();
    self.updateLastViewX();
}

fn killLine(self: *EditorController) !void {
    try self.buffer.killLine();
    self.updateLastViewX();
}

fn updateLastViewX(self: *EditorController) void {
    self.last_view_x = self.buffer_view.getCursor().x;
}

fn insertChar(self: *EditorController, char: u21) !void {
    try self.buffer.insertChar(char);
    self.updateLastViewX();
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

    for (self.buffer.rows.items) |row| row.deinit();
    self.buffer.rows.deinit();
    self.buffer.rows = new_rows;
    try self.buffer.notifyUpdate();

    self.file_path = path;

    const new_message = try fmt.allocPrint(self.allocator, "{s}", .{path});
    errdefer self.allocator.free(new_message);
    try self.status_message.setMessage(new_message);
}

fn saveFile(self: *EditorController) !void {
    var f = try fs.cwd().createFile(self.file_path.?, .{});
    defer f.close();
    for (self.buffer.rows.items, 0..) |row, i| {
        if (i > 0)
            _ = try f.write("\n");
        _ = try f.write(row.buffer.items);
    }
    const new_status = try fmt.allocPrint(self.allocator, "Saved: {s}", .{self.file_path.?});
    errdefer self.allocator.free(new_status);
    try self.status_message.setMessage(new_status);
}
