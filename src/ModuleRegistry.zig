const std = @import("std");
const Module = @import("Module.zig");

allocator: std.mem.Allocator,
modules: std.StringHashMap(Module),

pub fn init(allocator: std.mem.Allocator) @This() {
    return .{
        .allocator = allocator,
        .modules = std.StringHashMap(Module).init(allocator),
    };
}

pub fn deinit(self: *@This()) void {
    var module_it = self.modules.iterator();
    while (module_it.next()) |module| {
        self.allocator.free(module.key_ptr.*);
        module.value_ptr.deinit();
    }
    self.modules.deinit();
}

pub fn append(self: *@This(), module: Module) !void {
    const key = try self.allocator.dupe(u8, module.definition.name);
    errdefer self.allocator.free(key);
    try self.modules.putNoClobber(key, module);
}

pub fn get(self: *const @This(), name: []const u8) ?Module {
    return self.modules.get(name);
}
