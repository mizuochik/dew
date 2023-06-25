const std = @import("std");
const os = std.os;
const io = std.io;
const ascii = std.ascii;
const mem = std.mem;
const heap = std.heap;
const debug = std.debug;
const fmt = std.fmt;
const testing = std.testing;
const c = @import("c.zig");

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

const Editor = @This();

const Config = struct {
    orig_termios: os.termios,
    screen_size: WindowSize,
    c_x: i32 = 0,
    c_y: i32 = 0,
};

const Key = union(enum) {
    plain: u8,
    control: u8,
    arrow: Arrow,
};

const Arrow = enum {
    up,
    down,
    right,
    left,
};

allocator: mem.Allocator,
config: Config,

pub fn init(allocator: mem.Allocator) !Editor {
    const orig = try enableRawMode();
    const size = try getWindowSize();
    return Editor{
        .allocator = allocator,
        .config = Config{
            .orig_termios = orig,
            .screen_size = size,
        },
    };
}

pub fn deinit(self: *const Editor) !void {
    try self.disableRawMode();
    try self.doRender(clearScreen);
}

pub fn run(self: *Editor) !void {
    try self.doRender(clearScreen);
    while (true) {
        try self.doRender(refreshScreen);
        self.processKeypress(try readKey()) catch |err| switch (err) {
            error.Quit => return,
            else => return err,
        };
    }
}

fn ctrlKey(comptime key: u8) u8 {
    return key & 0x1f;
}

fn readKey() !Key {
    const k = try io.getStdIn().reader().readByte();
    if (k == 0x1b) {
        const esc = try io.getStdIn().reader().readByte();
        if (esc == '[') {
            const a = try io.getStdIn().reader().readByte();
            return .{
                .arrow = switch (a) {
                    'A' => .up,
                    'B' => .down,
                    'C' => .right,
                    'D' => .left,
                    else => unreachable,
                },
            };
        }
    }
    if (ascii.isControl(k)) {
        return switch (k) {
            ctrlKey('p') => .{ .arrow = .up },
            ctrlKey('n') => .{ .arrow = .down },
            ctrlKey('f') => .{ .arrow = .right },
            ctrlKey('b') => .{ .arrow = .left },
            else => .{ .control = k },
        };
    }
    return .{ .plain = k };
}

fn processKeypress(self: *Editor, key: Key) !void {
    switch (key) {
        .control => |k| if (k == ctrlKey('x')) {
            return error.Quit;
        } else {
            std.debug.print("{d}\r\n", .{k});
        },
        .plain => |k| {
            std.debug.print("{d} ({c})\r\n", .{ k, k });
        },
        .arrow => |k| switch (k) {
            .up => if (self.config.c_y > 0) {
                self.config.c_y -= 1;
            },
            .down => if (self.config.c_y < self.config.screen_size.rows - 1) {
                self.config.c_y += 1;
            },
            .left => if (self.config.c_x > 0) {
                self.config.c_x -= 1;
            },
            .right => if (self.config.c_x < self.config.screen_size.cols - 1) {
                self.config.c_x += 1;
            },
        },
    }
}

fn refreshScreen(self: *const Editor, arena: mem.Allocator, buf: *std.ArrayList(u8)) !void {
    try buf.appendSlice("\x1b[?25l");
    try buf.appendSlice("\x1b[H");
    try drawRows(buf);
    try buf.appendSlice(try fmt.allocPrint(arena, "\x1b[{d};{d}H", .{ self.config.c_y + 1, self.config.c_x + 1 }));
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

fn drawRows(buf: *std.ArrayList(u8)) !void {
    for (0..24) |_| {
        try buf.appendSlice("\x1b[K");
        try buf.appendSlice("~\r\n");
    }
    try buf.appendSlice("\x1b[H");
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
