const std = @import("std");
const dew = @import("../../dew.zig");

const CommandExecutor = @This();

buffer_selector: *dew.models.BufferSelector,
status_message: *dew.models.StatusMessage,
allocator: std.mem.Allocator,

pub fn eventSubscriber(self: *CommandExecutor) dew.event.Subscriber(dew.models.Event) {
    return .{
        .ptr = self,
        .vtable = &.{
            .handle = handleEvent,
        },
    };
}

pub fn handleEvent(ctx: *anyopaque, event: dew.models.Event) anyerror!void {
    const self: *CommandExecutor = @ptrCast(@alignCast(ctx));
    switch (event) {
        .command_executed => |command_line| {
            var parsed = try self.parseCommandLine(command_line.buffer.items);
            defer parsed.deinit();
            try parsed.command.run(self.allocator, parsed.arguments);
            try self.buffer_selector.toggleCommandBuffer();
        },
        else => {},
    }
}

const ParsedCommandLine = struct {
    allocator: std.mem.Allocator,
    command: dew.models.Command,
    arguments: [][]const u8,

    pub fn deinit(self: *const ParsedCommandLine) void {
        for (self.arguments) |arg| {
            self.allocator.free(arg);
        }
        self.allocator.free(self.arguments);
        self.command.deinit();
    }
};

pub fn parseCommandLine(self: *CommandExecutor, command_line: []const u8) !ParsedCommandLine {
    _ = command_line;
    var args = try self.allocator.alloc([]const u8, 1);
    errdefer self.allocator.free(args);
    args[0] = try std.fmt.allocPrint(self.allocator, "README.md", .{});
    errdefer self.allocator.free(args[0]);
    var cmd = try dew.models.Command.OpenFile.init(self.allocator, self.buffer_selector, self.status_message);
    errdefer cmd.deinit();
    return .{
        .allocator = self.allocator,
        .command = cmd,
        .arguments = args,
    };
}
