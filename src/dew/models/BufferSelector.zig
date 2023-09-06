const dew = @import("../../dew.zig");
const models = dew.models;

const Self = @This();

file_buffer: *models.Buffer,

pub fn init(file_buffer: *models.Buffer) Self {
    return .{
        .file_buffer = file_buffer,
    };
}

pub fn deinit(_: *const Self) void {
}
