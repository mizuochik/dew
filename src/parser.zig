const std = @import("std");

pub const Error = error{
    EndOfStream,
    InvalidInput,
};

pub fn Result(comptime Value: type) type {
    return struct {
        value: Value,
        rest: []const u8,
    };
}

pub fn anyCharacter(input: []const u8) Error!Result(u8) {
    if (input.len <= 0)
        return Error.EndOfStream;
    const c = input[0];
    return .{
        .value = c,
        .rest = input[1..],
    };
}

pub fn character(input: []const u8, c: u8) Error!Result(u8) {
    const ac = try anyCharacter(input);
    if (ac.value != c)
        return Error.InvalidInput;
    return .{
        .value = ac.value,
        .rest = ac.rest,
    };
}

pub fn singleNumber(input: []const u8) Error!Result(u8) {
    const l = try anyCharacter(input);
    const c = l.value;
    if (c < '0' or '9' < c)
        return Error.InvalidInput;
    return .{
        .value = c - '0',
        .rest = l.rest,
    };
}

pub fn number(input: []const u8) Error!Result(i32) {
    const first = try singleNumber(input);
    var accum = first.value;
    var rest = first.rest;
    while (singleNumber(rest)) |result| {
        accum = accum * 10 + result.value;
        rest = result.rest;
    } else |e| switch (e) {
        Error.EndOfStream, Error.InvalidInput => return .{
            .value = accum,
            .rest = rest,
        },
        else => return e,
    }
}

test "parse a character" {
    {
        const actual = try character("abc", 'a');
        try std.testing.expectEqual('a', actual.value);
    }
    {
        const actual = character("abc", 'b');
        try std.testing.expectError(Error.InvalidInput, actual);
    }
}

test "parser a number" {
    const actual = try number("123");
    try std.testing.expectEqual(123, actual.value);
}
