const std = @import("std");
const io = std.io;
const ascii = std.ascii;
const unicode = std.unicode;
const testing = std.testing;

const dew = @import("../dew.zig");
const Key = dew.models.Key;
const Arrow = dew.models.Arrow;

const Keyboard = @This();

fixed_buffer_stream: ?io.FixedBufferStream([]const u8) = null, // for testing only

pub fn inputKey(self: *Keyboard) !Key {
    var k = try self.readByte();
    if (k == 0x1b) {
        k = try self.readByte();
        if (k == '[') {
            k = try self.readByte();
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
    if (k == 0x7f) {
        return .del;
    }
    if (ascii.isControl(k)) {
        return .{ .ctrl = k + 0x40 };
    }
    var buf: [4]u8 = undefined;
    buf[0] = k;
    const l = try unicode.utf8ByteSequenceLength(k);
    for (1..l) |i| {
        buf[i] = try self.readByte();
    }
    return .{ .plain = try unicode.utf8Decode(buf[0..l]) };
}

fn readByte(self: *Keyboard) anyerror!u8 {
    if (self.fixed_buffer_stream) |*fixed| {
        return try fixed.reader().readByte();
    }
    return try io.getStdIn().reader().readByte();
}

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
        .{ .given = "\x7f", .expected = Key.del },
    };
    inline for (cases) |case| {
        var k = Keyboard{
            .fixed_buffer_stream = io.fixedBufferStream(case.given),
        };
        const actual = try k.inputKey();
        try testing.expectEqualDeep(case.expected, actual);
    }
}
