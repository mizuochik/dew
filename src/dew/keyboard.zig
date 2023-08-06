const std = @import("std");
const io = std.io;
const ascii = std.ascii;
const unicode = std.unicode;
const testing = std.testing;

const dew = @import("../dew.zig");

const Keyboard = @This();

const Self = @This();

reader: dew.Reader,

pub fn inputKey(self: *Self) !Key {
    var k = try self.reader.readByte();
    if (k == 0x1b) {
        k = try self.reader.readByte();
        if (k == '[') {
            k = try self.reader.readByte();
            switch (k) {
                'A' => return .{ .arrow = .up },
                'B' => return .{ .arrow = .down },
                'C' => return .{ .arrow = .right },
                'D' => return .{ .arrow = .left },
                else => {},
            }
        }
        return .{ .meta = k };
    }
    if (ascii.isControl(k)) {
        return .{ .ctrl = k + 0x40 };
    }
    var buf: [4]u8 = undefined;
    buf[0] = k;
    const l = try unicode.utf8ByteSequenceLength(k);
    for (1..l) |i| {
        buf[i] = try self.reader.readByte();
    }
    return .{ .plain = try unicode.utf8Decode(buf[0..l]) };
}

pub const Key = union(enum) {
    plain: u21,
    ctrl: u8,
    meta: u8,
    arrow: Arrow,
};

pub const Arrow = enum {
    up,
    down,
    right,
    left,
};

test "Keyboard: inputKey" {
    const cases = .{
        .{ .given = "\x00", .expected = Key{ .ctrl = '@' } },
        .{ .given = "\x08", .expected = Key{ .ctrl = 'H' } },
        .{ .given = "A", .expected = Key{ .plain = 'A' } },
        .{ .given = "あ", .expected = Key{ .plain = 'あ' } },
        .{ .given = "\x1b[A", .expected = Key{ .arrow = .up } },
        .{ .given = "\x1b[B", .expected = Key{ .arrow = .down } },
        .{ .given = "\x1b[C", .expected = Key{ .arrow = .right } },
        .{ .given = "\x1b[D", .expected = Key{ .arrow = .left } },
        .{ .given = "\x1bA", .expected = Key{ .meta = 'A' } },
        .{ .given = "\x1bz", .expected = Key{ .meta = 'z' } },
    };
    inline for (cases) |case| {
        var given = dew.Reader.Fixed.init(case.given);
        var given_reader = given.reader();
        var k = Keyboard{
            .reader = given_reader,
        };

        const actual = try k.inputKey();

        try testing.expectEqualDeep(case.expected, actual);
    }
}