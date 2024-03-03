const std = @import("std");

allocator: std.mem.Allocator,
name: []const u8,
options: std.StringArrayHashMap(Value),
positionals: []Value,
subcommand: ?*@This(),

pub const Value = union(enum) {
    int: i64,
    float: f64,
    str: []const u8,
    bool_: bool,
};

pub fn deinit(self: *@This()) void {
    self.allocator.free(self.name);

    var options = self.options.iterator();
    while (options.next()) |option| {
        self.allocator.free(option.key_ptr.*);
        switch (option.value_ptr.*) {
            .str => |s| self.allocator.free(s),
            else => {},
        }
    }
    self.options.deinit();

    for (self.positionals) |positional| {
        switch (positional) {
            .str => |s| self.allocator.free(s),
            else => {},
        }
    }
    self.allocator.free(self.positionals);

    if (self.subcommand) |subcommand|
        subcommand.deinit();
}
