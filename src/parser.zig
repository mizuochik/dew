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

pub fn singleNumber(input: []const u8) Error!Result(u8) {
    if (input.len <= 0)
        return Error.EndOfStream;
    const c = input[0];
    if (c < '0' or '9' < c)
        return Error.InvalidInput;
    return .{
        .value = c - '0',
        .rest = input[1..],
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

test "parser a number" {
    const actual = try number("123");
    try std.testing.expectEqual(123, actual.value);
}
