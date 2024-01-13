const std = @import("std");
const models = @import("models.zig");

fixed_buffer_stream: ?std.io.FixedBufferStream([]const u8) = null, // for testing only

pub fn inputKey(self: *@This()) !models.Key {
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
        .{ .given = "\x00", .expected = models.Key{ .ctrl = '@' } },
        .{ .given = "\x08", .expected = models.Key{ .ctrl = 'H' } },
        .{ .given = "A", .expected = models.Key{ .plain = 'A' } },
        .{ .given = "あ", .expected = models.Key{ .plain = 'あ' } },
        .{ .given = "\x1b[A", .expected = models.Key{ .arrow = .up } },
        .{ .given = "\x1b[B", .expected = models.Key{ .arrow = .down } },
        .{ .given = "\x1b[C", .expected = models.Key{ .arrow = .right } },
        .{ .given = "\x1b[D", .expected = models.Key{ .arrow = .left } },
        .{ .given = "\x1bA", .expected = models.Key{ .meta = 'A' } },
        .{ .given = "\x1bz", .expected = models.Key{ .meta = 'z' } },
        .{ .given = "\x7f", .expected = models.Key.del },
    };
    inline for (cases) |case| {
        var k = @This(){
            .fixed_buffer_stream = std.io.fixedBufferStream(case.given),
        };
        const actual = try k.inputKey();
        try std.testing.expectEqualDeep(case.expected, actual);
    }
}
