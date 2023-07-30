const std = @import("std");
const io = std.io;
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
