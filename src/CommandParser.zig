const std = @import("std");
const BufferSelector = @import("BufferSelector.zig");
const Status = @import("Status.zig");
const CommandLine = @import("CommandLine.zig");
const parser = @import("parser.zig");

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
    var state: parser.State = .{
        .input = input,
        .allocator = self.allocator,
    };
    return Parser.commandLine(&state);
}

const Parser = struct {
    fn commandLine(state: *parser.State) !CommandLine {
        const in = state.input;
        errdefer state.input = in;
        parser.spaces(state) catch {};
        const method_name = try name(state);
        errdefer state.allocator.free(method_name);
        var params = std.ArrayList([]const u8).init(state.allocator);
        errdefer {
            for (params.items) |param| state.allocator.free(param);
            params.deinit();
        }
        while (true) {
            parser.spaces(state) catch break;
            const arg = argument(state) catch doubleQuotedArgument(state) catch break;
            errdefer state.allocator.free(arg);
            try params.append(arg);
        }
        try parser.endOfInput(state);
        return .{
            .allocator = state.allocator,
            .method_name = method_name,
            .params = try params.toOwnedSlice(),
            .arguments = &.{
                .allocator = state.allocator,
                .optionals = std.StringHashMap([]const u8).init(state.allocator),
                .positionals = &[_][]const u8{},
            },
        };
    }

    fn argument(state: *parser.State) ![]const u8 {
        return name(state);
    }

    fn name(state: *parser.State) ![]const u8 {
        const in = state.input;
        errdefer state.input = in;
        var cs = std.ArrayList(u8).init(state.allocator);
        errdefer cs.deinit();
        const head = try nameCharacter(state);
        try cs.append(head);
        while (nameCharacter(state)) |c|
            try cs.append(c)
        else |_|
            return cs.toOwnedSlice();
    }

    fn nameCharacter(state: *parser.State) !u8 {
        return parser.letter(state) catch parser.digit(state) catch parser.anyCharacter(state, "-_./[]{}");
    }

    fn doubleQuotedArgument(state: *parser.State) ![]const u8 {
        const in = state.input;
        errdefer state.input = in;
        _ = try parser.anyCharacter(state, "\"");
        const arg = try argument(state);
        errdefer state.allocator.free(arg);
        _ = try parser.anyCharacter(state, "\"");
        return arg;
    }
};
