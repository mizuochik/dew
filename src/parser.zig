const std = @import("std");

pub const State = struct {
    input: []const u8,
    allocator: std.mem.Allocator,
    errorMessage: ?[]const u8 = null,

    pub fn deinit(self: *const State) void {
        if (self.errorMessage) |message|
            self.allocator.free(message);
    }
};

pub const Error = error{
    EndOfInput,
    InvalidInput,
};

pub fn Result(comptime Value: type) type {
    return struct {
        value: Value,
    };
}

pub fn anyCharacter(state: *State, characters: ?[]const u8) Error!u8 {
    if (state.input.len <= 0)
        return Error.EndOfInput;
    const c = state.input[0];
    if (characters) |cs|
        _ = std.mem.indexOfScalar(u8, cs, c) orelse return Error.InvalidInput;
    state.input = state.input[1..];
    return c;
}

pub fn character(state: *State, c: u8) Error!u8 {
    return try anyCharacter(state, &[_]u8{c});
}

pub fn letter(state: *State) Error!u8 {
    const in = state.input;
    errdefer state.input = in;
    const c = try anyCharacter(state, null);
    if ('A' <= c and c <= 'Z' or 'a' <= c and c <= 'z')
        return c;
    return Error.InvalidInput;
}

pub fn spaces(state: *State) Error!void {
    _ = try character(state, ' ');
    while (true)
        _ = character(state, ' ') catch return;
}

pub fn singleNumber(state: *State) Error!u8 {
    const in = state.input;
    errdefer state.input = in;
    const c = try anyCharacter(state, null);
    if (c < '0' or '9' < c)
        return Error.EndOfInput;
    return c - '0';
}

pub fn number(state: *State) Error!i32 {
    const in = state.input;
    errdefer state.input = in;
    var accum = try singleNumber(state);
    while (singleNumber(state)) |value| {
        accum = accum * 10 + value;
    } else |e| switch (e) {
        Error.EndOfInput, Error.InvalidInput => return accum,
        else => return e,
    }
}

pub fn endOfInput(state: *const State) Error!void {
    if (state.input.len > 0)
        return Error.InvalidInput;
}

test "parse a character" {
    {
        var state: State = .{
            .input = "abc",
            .allocator = std.testing.allocator,
        };
        defer state.deinit();
        const actual = try character(&state, 'a');
        try std.testing.expectEqual('a', actual);
    }
    {
        var state: State = .{
            .input = "abc",
            .allocator = std.testing.allocator,
        };
        defer state.deinit();
        const actual = character(&state, 'b');
        try std.testing.expectError(Error.InvalidInput, actual);
    }
}

test "parser a number" {
    var state: State = .{
        .input = "123",
        .allocator = std.testing.allocator,
    };
    defer state.deinit();
    const actual = try number(&state);
    try std.testing.expectEqual(123, actual);
}

test "parse end of input" {
    {
        var state: State = .{
            .input = "",
            .allocator = std.testing.allocator,
        };
        defer state.deinit();
        _ = try endOfInput(&state);
    }
    {
        var state: State = .{
            .input = " ",
            .allocator = std.testing.allocator,
        };
        defer state.deinit();
        try std.testing.expectError(Error.InvalidInput, endOfInput(&state));
    }
}

test "parse spaces" {
    var state: State = .{
        .input = "  abc",
        .allocator = std.testing.allocator,
    };
    defer state.deinit();
    _ = try spaces(&state);
    try std.testing.expectEqualStrings("abc", state.input);
}

test "parse a letter" {
    const Case = struct {
        char: u8,
        expected: Error!u8,
    };
    const cases = [_]Case{
        .{ .char = '@', .expected = Error.InvalidInput },
        .{ .char = 'A', .expected = 'A' },
        .{ .char = 'Z', .expected = 'Z' },
        .{ .char = '[', .expected = Error.InvalidInput },
        .{ .char = '`', .expected = Error.InvalidInput },
        .{ .char = 'a', .expected = 'a' },
        .{ .char = 'z', .expected = 'z' },
        .{ .char = '{', .expected = Error.InvalidInput },
    };
    inline for (cases) |case| {
        var state: State = .{
            .input = &[_]u8{case.char},
            .allocator = std.testing.allocator,
        };
        const actual = letter(&state);
        try std.testing.expectEqual(case.expected, actual);
    }
}
