const std = @import("std");

pub const Key = union(enum) {
    plain: u21,
    ctrl: u8,
    meta: u8,
    arrow: Arrow,
    del,
};

pub const Arrow = enum {
    up,
    down,
    right,
    left,
};

fixed_buffer_stream: ?std.io.FixedBufferStream([]const u8) = null, // for testing only

pub fn inputKey(self: *@This()) !Key {
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
    if (std.ascii.isControl(k)) {
        return .{ .ctrl = k + 0x40 };
    }
    var buf: [4]u8 = undefined;
    buf[0] = k;
    const l = try std.unicode.utf8ByteSequenceLength(k);
    for (1..l) |i| {
        buf[i] = try self.readByte();
    }
    return .{ .plain = try std.unicode.utf8Decode(buf[0..l]) };
}

fn readByte(self: *@This()) anyerror!u8 {
    if (self.fixed_buffer_stream) |*fixed| {
        return try fixed.reader().readByte();
    }
    return try std.io.getStdIn().reader().readByte();
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
        var k = @This(){
            .fixed_buffer_stream = std.io.fixedBufferStream(case.given),
        };
        const actual = try k.inputKey();
        try std.testing.expectEqualDeep(case.expected, actual);
    }
}
