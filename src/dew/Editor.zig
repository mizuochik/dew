const std = @import("std");
const os = std.os;
const io = std.io;
const ascii = std.ascii;
const mem = std.mem;
const heap = std.heap;
const debug = std.debug;
const fmt = std.fmt;
const fs = std.fs;
const unicode = std.unicode;
const testing = std.testing;
const dew = @import("../dew.zig");
const Buffer = dew.models.Buffer;
const Key = dew.models.Key;
const Arrow = dew.models.Arrow;
const UnicodeString = dew.models.UnicodeString;
const c = dew.c;
const BufferController = dew.controllers.BufferController;

const darwin_ECHO: os.tcflag_t = 0x8;
const darwin_ICANON: os.tcflag_t = 0x100;
const darwin_ISIG: os.tcflag_t = 0x80;
const darwin_IXON: os.tcflag_t = 0x200;
const darwin_IEXTEN: os.tcflag_t = 0x400;
const darwin_ICRNL: os.tcflag_t = 0x100;
const darwin_OPOST: os.tcflag_t = 0x1;
const darwin_BRKINT: os.tcflag_t = 0x2;
const darwin_INPCK: os.tcflag_t = 0x10;
const darwin_ISTRIP: os.tcflag_t = 0x20;
const darwin_CS8: os.tcflag_t = 0x300;

const ControlKeys = enum(u8) {
    DEL = 127,
    RETURN = 0x0d,
};

const Editor = @This();

const Config = struct {
    orig_termios: os.termios,
};

allocator: mem.Allocator,
config: Config,
buffer_controller: *BufferController,
keyboard: dew.Keyboard,

pub fn init(allocator: mem.Allocator) !Editor {
    const orig = try enableRawMode();
    const size = try getWindowSize();

    var buffer_controller = try allocator.create(BufferController);
    errdefer allocator.destroy(buffer_controller);
    buffer_controller.* = try BufferController.init(allocator, size.cols, size.rows);
    errdefer buffer_controller.deinit();

    return Editor{
        .allocator = allocator,
        .config = Config{
            .orig_termios = orig,
        },
        .buffer_controller = buffer_controller,
        .keyboard = dew.Keyboard{},
    };
}

pub fn deinit(self: *const Editor) !void {
    try self.disableRawMode();
    try self.doRender(clearScreen);
    self.buffer_controller.deinit();
    self.allocator.destroy(self.buffer_controller);
}

pub fn run(self: *Editor) !void {
    try self.doRender(clearScreen);
    while (true) {
        try self.doRender(refreshScreen);
        const key = try self.keyboard.inputKey();
        self.buffer_controller.processKeypress(key) catch |err| switch (err) {
            error.Quit => return,
            else => return err,
        };
    }
}

fn refreshScreen(self: *const Editor, arena: mem.Allocator, buf: *std.ArrayList(u8)) !void {
    try self.buffer_controller.buffer.notifyUpdate();
    try buf.appendSlice("\x1b[?25l");
    try buf.appendSlice("\x1b[H");
    try self.drawRows(buf);
    const cursor = self.buffer_controller.buffer_view.getCursor();
    const cursor_y = if (cursor.y <= self.buffer_controller.buffer_view.y_scroll)
        0
    else
        cursor.y - self.buffer_controller.buffer_view.y_scroll;
    try buf.appendSlice(try fmt.allocPrint(arena, "\x1b[{d};{d}H", .{ cursor_y + 1, cursor.x + 1 }));
    try buf.appendSlice("\x1b[?25h");
}

fn clearScreen(_: *const Editor, _: mem.Allocator, buf: *std.ArrayList(u8)) !void {
    try buf.appendSlice("\x1b[2J");
    try buf.appendSlice("\x1b[H");
}

fn doRender(self: *const Editor, render: *const fn (self: *const Editor, arena: mem.Allocator, buf: *std.ArrayList(u8)) anyerror!void) !void {
    var arena = heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var buf = std.ArrayList(u8).init(self.allocator);
    defer buf.deinit();
    try render(self, arena.allocator(), &buf);
    try io.getStdOut().writeAll(buf.items);
}

fn enableRawMode() !os.termios {
    const orig = try os.tcgetattr(os.STDIN_FILENO);
    var term = orig;
    term.iflag &= ~(darwin_BRKINT | darwin_IXON | darwin_ICRNL | darwin_INPCK | darwin_ISTRIP);
    term.oflag &= ~darwin_OPOST;
    term.cflag |= darwin_CS8;
    term.lflag &= ~(darwin_ECHO | darwin_ICANON | darwin_IEXTEN | darwin_ISIG);
    try os.tcsetattr(os.STDIN_FILENO, os.TCSA.FLUSH, term);
    return orig;
}

fn disableRawMode(self: *const Editor) !void {
    try os.tcsetattr(os.STDIN_FILENO, os.TCSA.FLUSH, self.config.orig_termios);
}

fn drawRows(self: *const Editor, buf: *std.ArrayList(u8)) !void {
    for (0..self.buffer_controller.buffer_view.height) |y| {
        if (y > 0) try buf.appendSlice("\r\n");
        try buf.appendSlice("\x1b[K");
        try buf.appendSlice(self.buffer_controller.buffer_view.getRowView(y + self.buffer_controller.buffer_view.y_scroll));
    }
    try buf.appendSlice("\r\n");
    try buf.appendSlice("\x1b[K");
    try buf.appendSlice(self.buffer_controller.status_message);
}

const WindowSize = struct {
    rows: u32,
    cols: u32,
};

fn getWindowSize() !WindowSize {
    var ws: c.winsize = undefined;
    const status = c.ioctl(io.getStdOut().handle, c.TIOCGWINSZ, &ws);
    if (status != 0) {
        return error.UnknownWinsize;
    }
    return WindowSize{
        .rows = ws.ws_row,
        .cols = ws.ws_col,
    };
}

test "getWindowSize" {
    const size = try getWindowSize();
    try testing.expect(size.rows > 0);
    try testing.expect(size.cols > 0);
}
