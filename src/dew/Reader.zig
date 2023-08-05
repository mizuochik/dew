const std = @import("std");
const io = std.io;
const testing = std.testing;
const Reader = @This();

ptr: *anyopaque,
vtable: VTable,

pub const VTable = struct {
    readByte: *const fn (ctx: *anyopaque) anyerror!u8,
};

pub fn readByte(self: *const Reader) !u8 {
    return self.vtable.readByte(self.ptr);
}

pub const stdin = Reader{
    .ptr = undefined,
    .vtable = .{
        .readByte = readByteStdin,
    },
};

fn readByteStdin(_: *anyopaque) anyerror!u8 {
    return try io.getStdIn().reader().readByte();
}

pub const Fixed = struct {
    stream: io.FixedBufferStream([]const u8),

    pub fn init(body: []const u8) Fixed {
        return .{
            .stream = io.fixedBufferStream(body),
        };
    }

    pub fn reader(self: *Fixed) Reader {
        return .{
            .ptr = self,
            .vtable = .{
                .readByte = readByteFixed,
            },
        };
    }

    fn readByteFixed(ctx: *anyopaque) anyerror!u8 {
        var self = @ptrCast(*Fixed, @alignCast(@alignOf(Fixed), ctx));
        return try self.stream.reader().readByte();
    }
};

test "Reader.Fixed: readByte" {
    var f = Fixed.init("hello");
    const r = f.reader();
    try testing.expectEqual(@as(u8, 'h'), try r.readByte());
    try testing.expectEqual(@as(u8, 'e'), try r.readByte());
    try testing.expectEqual(@as(u8, 'l'), try r.readByte());
    try testing.expectEqual(@as(u8, 'l'), try r.readByte());
    try testing.expectEqual(@as(u8, 'o'), try r.readByte());
    try testing.expectError(error.EndOfStream, r.readByte());
}
