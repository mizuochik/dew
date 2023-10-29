const std = @import("std");
const dew = @import("../dew.zig");

const Keyboard = @This();

fixed_buffer_stream: ?std.io.FixedBufferStream([]const u8) = null, // for testing only

pub fn inputKey(self: *Keyboard) !dew.models.Key {
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

fn readByte(self: *Keyboard) anyerror!u8 {
    if (self.fixed_buffer_stream) |*fixed| {
        return try fixed.reader().readByte();
    }
    return try std.io.getStdIn().reader().readByte();
}

test "Keyboard: inputKey" {
    const cases = .{
        .{ .given = "\x00", .expected = dew.models.Key{ .ctrl = '@' } },
        .{ .given = "\x08", .expected = dew.models.Key{ .ctrl = 'H' } },
        .{ .given = "A", .expected = dew.models.Key{ .plain = 'A' } },
        .{ .given = "あ", .expected = dew.models.Key{ .plain = 'あ' } },
        .{ .given = "\x1b[A", .expected = dew.models.Key{ .arrow = .up } },
        .{ .given = "\x1b[B", .expected = dew.models.Key{ .arrow = .down } },
        .{ .given = "\x1b[C", .expected = dew.models.Key{ .arrow = .right } },
        .{ .given = "\x1b[D", .expected = dew.models.Key{ .arrow = .left } },
        .{ .given = "\x1bA", .expected = dew.models.Key{ .meta = 'A' } },
        .{ .given = "\x1bz", .expected = dew.models.Key{ .meta = 'z' } },
        .{ .given = "\x7f", .expected = dew.models.Key.del },
    };
    inline for (cases) |case| {
        var k = Keyboard{
            .fixed_buffer_stream = std.io.fixedBufferStream(case.given),
        };
        const actual = try k.inputKey();
        try std.testing.expectEqualDeep(case.expected, actual);
    }
}
