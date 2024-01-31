const std = @import("std");
const BufferSelector = @import("BufferSelector.zig");
const Status = @import("Status.zig");
const CommandLine = @import("CommandLine.zig");

allocator: std.mem.Allocator,
input: [][]const u8,
index: usize,
buffer_selector: *BufferSelector,
status: *Status,

const ParseError = error{
    EOL,
    Unexpected,
};

pub fn init(allocator: std.mem.Allocator, buffer_selector: *BufferSelector, status: *Status) !@This() {
    const in = try allocator.alloc([]u8, 0);
    errdefer allocator.free(in);
    return .{
        .allocator = allocator,
        .input = in,
        .index = 0,
        .buffer_selector = buffer_selector,
        .status = status,
    };
}

pub fn deinit(self: *const @This()) void {
    for (self.input) |cp| {
        self.allocator.free(cp);
    }
    self.allocator.free(self.input);
}

pub fn parse(self: *@This(), input: []const u8) !CommandLine {
    try self.setInput(input);
    const method_name = try self.parseMethodName();
    errdefer self.allocator.free(method_name);
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
        .method_name = method_name,
        .params = args,
    };
}

fn setInput(self: *@This(), input: []const u8) !void {
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

fn parseMethodName(self: *@This()) ![]const u8 {
    var method_name_al = std.ArrayList(u8).init(self.allocator);
    defer method_name_al.deinit();
    try method_name_al.appendSlice(try self.parseAnyLetter());
    while (self.parseAnyLetter()) |letter| {
        try method_name_al.appendSlice(letter);
    } else |_| {}
    return try method_name_al.toOwnedSlice();
}

fn parseCharacter(self: *@This(), character: []const u8) !void {
    if (self.index >= self.input.len) {
        return ParseError.EOL;
    }
    if (!std.mem.eql(u8, self.input[self.index], character)) {
        return ParseError.Unexpected;
    }
    self.index += 1;
}

fn parseAnyLetter(self: *@This()) ![]const u8 {
    if (self.index >= self.input.len) {
        return ParseError.EOL;
    }
    if (std.mem.eql(u8, " ", self.input[self.index])) {
        return ParseError.Unexpected;
    }
    const r = self.input[self.index];
    self.index += 1;
    return r;
}

fn parseSpaces(self: *@This()) !void {
    if (self.index >= self.input.len) {
        return ParseError.EOL;
    }
    if (!std.mem.eql(u8, " ", self.input[self.index])) {
        return ParseError.Unexpected;
    }
    self.index += 1;
    while (self.index < self.input.len and std.mem.eql(u8, " ", self.input[self.index])) {
        self.index += 1;
    }
}

fn parseArgument(self: *@This()) ![]const u8 {
    var cmd = std.ArrayList(u8).init(self.allocator);
    errdefer cmd.deinit();
    if (self.parseCharacter("\"")) {
        while (true) {
            if (self.parseCharacter("\"")) {
                break;
            } else |_| {}
            const l = self.parseAnyLetter() catch break;
            try cmd.appendSlice(l);
        }
    } else |_| {
        while (true) {
            const l = self.parseAnyLetter() catch break;
            try cmd.appendSlice(l);
        }
    }
    return cmd.toOwnedSlice();
}
