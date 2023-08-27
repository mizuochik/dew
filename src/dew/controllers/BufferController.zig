const std = @import("std");
const fs = std.fs;
const fmt = std.fmt;
const Allocator = std.mem.Allocator;

const dew = @import("../../dew.zig");
const Key = dew.models.Key;
const models = dew.models;
const EventPublisher = dew.event.EventPublisher;
const EventSubscriber = dew.event.EventSubscriber;
const Arrow = dew.models.Arrow;
const Buffer = dew.models.Buffer;
const UnicodeString = dew.models.UnicodeString;

buffer: *dew.models.Buffer,
buffer_view: *dew.view.BufferView,
last_view_x: usize = 0,
status_message: []const u8,
file_path: ?[]const u8 = null,
model_event_publisher: *EventPublisher(dew.models.Event),
allocator: Allocator,

const BufferController = @This();

pub fn init(allocator: Allocator, cols: usize, rows: usize) !BufferController {
    const model_event_publisher = try allocator.create(EventPublisher(models.Event));
    errdefer allocator.destroy(model_event_publisher);
    model_event_publisher.* = EventPublisher(models.Event).init(allocator);
    errdefer model_event_publisher.deinit();

    const status = try fmt.allocPrint(allocator, "Initialized", .{});
    errdefer allocator.free(status);

    const buffer = try allocator.create(Buffer);
    errdefer allocator.destroy(buffer);
    buffer.* = Buffer.init(allocator, model_event_publisher);
    errdefer buffer.deinit();

    const buffer_view = try allocator.create(dew.view.BufferView);
    errdefer allocator.destroy(buffer_view);
    buffer_view.* = try dew.view.BufferView.init(allocator, buffer);
    errdefer buffer_view.deinit();
    try model_event_publisher.addSubscriber(buffer_view.eventSubscriber());
    try model_event_publisher.publish(models.Event{ .screen_size_changed = .{ .width = cols, .height = rows } });

    return BufferController{
        .allocator = allocator,
        .buffer = buffer,
        .buffer_view = buffer_view,
        .status_message = status,
        .model_event_publisher = model_event_publisher,
    };
}

pub fn deinit(self: *const BufferController) void {
    self.buffer_view.deinit();
    self.allocator.destroy(self.buffer_view);
    self.buffer.deinit();
    self.model_event_publisher.deinit();
    self.allocator.destroy(self.model_event_publisher);
    self.allocator.destroy(self.buffer);
    self.allocator.free(self.status_message);
}

pub fn processKeypress(self: *BufferController, key: Key) !void {
    switch (key) {
        .del => try self.deleteBackwardChar(),
        .ctrl => |k| switch (k) {
            'Q' => return error.Quit,
            'S' => try self.saveFile(),
            'K' => try self.killLine(),
            'D' => try self.deleteChar(),
            'H' => try self.deleteBackwardChar(),
            'M' => try self.breakLine(),
            'P' => self.moveCursor(.up),
            'N' => self.moveCursor(.down),
            'F' => self.moveCursor(.right),
            'B' => self.moveCursor(.left),
            'J' => try self.buffer.joinLine(),
            'A' => {
                self.buffer.moveToBeginningOfLine();
                self.updateLastViewX();
            },
            'E' => {
                self.buffer.moveToEndOfLine();
                self.updateLastViewX();
            },
            'V' => {
                self.buffer_view.scrollDown(self.buffer_view.height * 15 / 16);
                const cur = self.buffer_view.getNormalizedCursor();
                self.buffer.setCursor(cur.x, cur.y);
            },
            else => {},
        },
        .meta => |k| switch (k) {
            'v' => {
                self.buffer_view.scrollUp(self.buffer_view.height * 15 / 16);
                const cur = self.buffer_view.getNormalizedCursor();
                self.buffer.setCursor(cur.x, cur.y);
            },
            else => {},
        },
        .plain => |k| try self.insertChar(k),
        .arrow => |k| self.moveCursor(k),
    }
}

fn moveCursor(self: *BufferController, k: Arrow) void {
    switch (k) {
        .up => {
            const y = self.buffer_view.getCursor().y;
            if (y > 0) {
                const new_cursor = self.buffer_view.getBufferPopsition(.{ .x = self.last_view_x, .y = y - 1 });
                self.buffer.setCursor(new_cursor.x, new_cursor.y);
            }
        },
        .down => {
            const y = self.buffer_view.getCursor().y;
            if (y < self.buffer_view.getNumberOfLines() - 1) {
                const new_cursor = self.buffer_view.getBufferPopsition(.{ .x = self.last_view_x, .y = y + 1 });
                self.buffer.setCursor(new_cursor.x, new_cursor.y);
            }
        },
        .left => {
            self.buffer.moveBackward();
            self.updateLastViewX();
        },
        .right => {
            self.buffer.moveForward();
            self.updateLastViewX();
        },
    }
    self.buffer_view.normalizeScroll();
}

fn deleteChar(self: *BufferController) !void {
    try self.buffer.deleteChar();
    self.updateLastViewX();
}

fn deleteBackwardChar(self: *BufferController) !void {
    try self.buffer.deleteBackwardChar();
    self.updateLastViewX();
}

fn breakLine(self: *BufferController) !void {
    try self.buffer.breakLine();
    self.updateLastViewX();
}

fn killLine(self: *BufferController) !void {
    try self.buffer.killLine();
    self.updateLastViewX();
}

fn updateLastViewX(self: *BufferController) void {
    self.last_view_x = self.buffer_view.getCursor().x;
}

fn insertChar(self: *BufferController, char: u21) !void {
    try self.buffer.insertChar(char);
    self.updateLastViewX();
}

pub fn openFile(self: *BufferController, path: []const u8) !void {
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
}

fn saveFile(self: *BufferController) !void {
    var f = try fs.cwd().createFile(self.file_path.?, .{});
    defer f.close();
    for (self.buffer.rows.items, 0..) |row, i| {
        if (i > 0)
            _ = try f.write("\n");
        _ = try f.write(row.buffer.items);
    }
    const new_status = try fmt.allocPrint(self.allocator, "Saved: {s}", .{self.file_path.?});
    errdefer self.allocator.free(new_status);
    self.setStatusMessage(new_status);
}

fn setStatusMessage(self: *BufferController, status_message: []const u8) void {
    self.allocator.free(self.status_message);
    self.status_message = status_message;
}
