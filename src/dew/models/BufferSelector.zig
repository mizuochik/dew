const dew = @import("../../dew.zig");
const models = dew.models;

const Self = @This();

file_buffer: *models.Buffer,
command_buffer: *models.Buffer,
event_publisher: *const dew.event.Publisher(models.Event),

pub fn init(file_buffer: *models.Buffer, command_buffer: *models.Buffer, event_publisher: *const dew.event.Publisher(models.Event)) Self {
    return .{
        .file_buffer = file_buffer,
        .command_buffer = command_buffer,
        .event_publisher = event_publisher,
    };
}

pub fn deinit(_: *const Self) void {}
