const std = @import("std");
const BufferSelector = @import("BufferSelector.zig");
const StatusMessage = @import("StatusMessage.zig");

allocator: std.mem.Allocator,
input: [][]const u8,
index: usize,
buffer_selector: *BufferSelector,
status_message: *StatusMessage,

const CommandParser = @This();

pub const CommandLine = struct {
    allocator: std.mem.Allocator,
    command_name: []const u8,
    arguments: [][]const u8,

    pub fn deinit(self: *const CommandLine) void {
        self.allocator.free(self.command_name);
        for (self.arguments) |argument| {
            self.allocator.free(argument);
        }
        self.allocator.free(self.arguments);
    }
};

const Error = error{
    EOL,
    Error,
};

pub fn init(allocator: std.mem.Allocator, buffer_selector: *BufferSelector, status_message: *StatusMessage) !CommandParser {
    const in = try allocator.alloc([]u8, 0);
    errdefer allocator.free(in);
    return .{
        .allocator = allocator,
        .input = in,
        .index = 0,
        .buffer_selector = buffer_selector,
        .status_message = status_message,
    };
}

pub fn deinit(self: *const CommandParser) void {
    for (self.input) |cp| {
        self.allocator.free(cp);
    }
    self.allocator.free(self.input);
}

pub fn parse(self: *CommandParser, input: []const u8) !CommandLine {
    try self.setInput(input);
    const command_name = try self.parseCommandName();
    errdefer self.allocator.free(command_name);
    var arg_list = std.ArrayList([]const u8).init(self.allocator);
    errdefer {
        for (arg_list.items) |arg| self.allocator.free(arg);
        arg_list.deinit();
    }
    while (true) {
        self.parseSpaces() catch break;
        const arg = self.parseArgument() catch break;
        errdefer self.allocator.free(arg);
        try arg_list.append(arg);
    }
    const args = try arg_list.toOwnedSlice();
    errdefer self.allocator.free(args);
    return .{
        .allocator = self.allocator,
        .command_name = command_name,
        .arguments = args,
    };
}

fn setInput(self: *CommandParser, input: []const u8) !void {
    const view = try std.unicode.Utf8View.init(input);
    var it = view.iterator();
    var cps = std.ArrayList([]const u8).init(self.allocator);
    errdefer {
        for (cps.items) |cp| {
            self.allocator.free(cp);
        }
        cps.deinit();
    }
    while (it.nextCodepointSlice()) |s| {
        const ss = try std.fmt.allocPrint(self.allocator, "{s}", .{s});
        errdefer self.allocator.free(ss);
        try cps.append(ss);
    }
    const in = try cps.toOwnedSlice();
    errdefer self.allocator.free(in);
    for (self.input) |cp| {
        self.allocator.free(cp);
    }
    self.allocator.free(self.input);
    self.input = in;
}

fn parseCommandName(self: *CommandParser) ![]const u8 {
    var command_name_al = std.ArrayList(u8).init(self.allocator);
    defer command_name_al.deinit();
    try command_name_al.appendSlice(try self.parseAnyLetter());
    while (self.parseAnyLetter()) |letter| {
        try command_name_al.appendSlice(letter);
    } else |_| {}
    return try command_name_al.toOwnedSlice();
}

fn parseAnyLetter(self: *CommandParser) ![]const u8 {
    if (self.index >= self.input.len) {
        return Error.EOL;
    }
    if (std.mem.eql(u8, " ", self.input[self.index])) {
        return Error.Error;
    }
    const r = self.input[self.index];
    self.index += 1;
    return r;
}

fn parseSpaces(self: *CommandParser) !void {
    if (self.index >= self.input.len) {
        return Error.EOL;
    }
    if (!std.mem.eql(u8, " ", self.input[self.index])) {
        return Error.Error;
    }
    self.index += 1;
    while (self.index < self.input.len and std.mem.eql(u8, " ", self.input[self.index])) {
        self.index += 1;
    }
}

fn parseArgument(self: *CommandParser) ![]const u8 {
    var cmd = std.ArrayList(u8).init(self.allocator);
    errdefer cmd.deinit();
    try cmd.appendSlice(try self.parseAnyLetter());
    while (self.parseAnyLetter()) |letter| {
        try cmd.appendSlice(letter);
    } else |_| {}
    return cmd.toOwnedSlice();
}
