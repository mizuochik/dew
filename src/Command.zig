const std = @import("std");

allocator: std.mem.Allocator,
name: []const u8,
options: std.StringArrayHashMap([]const u8),
positionals: []const []const u8,
subcommand: ?*@This(),

pub fn deinit(self: *@This()) void {
    self.allocator.free(self.name);

    var options = self.options.iterator();
    while (options.next()) |option| {
        self.allocator.free(option.key_ptr.*);
        self.allocator.free(option.value_ptr.*);
    }
    self.options.deinit();

    for (self.positionals) |positional|
        self.allocator.free(positional);
    self.allocator.free(self.positionals);

    if (self.subcommand) |subcommand|
        subcommand.deinit();
}
