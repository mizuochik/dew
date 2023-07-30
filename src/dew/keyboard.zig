const std = @import("std");
const io = std.io;
const ascii = std.ascii;
const unicode = std.unicode;
const testing = std.testing;

pub fn Keyboard(comptime Reader: type) type {
    return struct {
        const Self = @This();

        reader: Reader,

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
            }
            if (ascii.isControl(k)) {
                return .{ .ctrl = k & 0x1f };
            }
            var buf: [4]u8 = undefined;
            buf[0] = k;
            const l = try unicode.utf8ByteSequenceLength(k);
            for (1..l) |i| {
                buf[i] = try self.reader.readByte();
            }
            return .{ .plain = try unicode.utf8Decode(buf[0..l]) };
        }
    };
}

const Key = union(enum) {
    plain: u21,
    ctrl: u8,
    meta: u8,
    arrow: enum {
        up,
        down,
        right,
        left,
    },
};

test "Keyboard: inputKey" {
    const cases = .{
        .{ .given = "\x00", .expected = Key{ .ctrl = 0x00 } },
        .{ .given = "\x08", .expected = Key{ .ctrl = 0x08 } },
        .{ .given = "A", .expected = Key{ .plain = 'A' } },
        .{ .given = "あ", .expected = Key{ .plain = 'あ' } },
        .{ .given = "\x1b[A", .expected = Key{ .arrow = .up } },
        .{ .given = "\x1b[B", .expected = Key{ .arrow = .down } },
        .{ .given = "\x1b[C", .expected = Key{ .arrow = .right } },
        .{ .given = "\x1b[D", .expected = Key{ .arrow = .left } },
    };
    inline for (cases) |case| {
        var given_buf = io.fixedBufferStream(case.given);
        var given_reader = given_buf.reader();
        var k = Keyboard(@TypeOf(given_reader)){
            .reader = given_reader,
        };

        const actual = try k.inputKey();

        try testing.expectEqualDeep(case.expected, actual);
    }
}
