const Resource = @This();
const std = @import("std");
const Editor = @import("Editor.zig");

pub const Method = *const fn (editor: *Editor, params: [][]const u8) anyerror!void;

allocator: std.mem.Allocator,
methods: std.StringHashMap(Method),

pub fn init(allocator: std.mem.Allocator) Resource {
    return .{
        .allocator = allocator,
        .methods = std.StringHashMap(Method).init(allocator),
    };
}

pub fn deinit(self: *Resource) void {
    var keys = self.methods.keyIterator();
    while (keys.next()) |key| {
        self.removeMethod(key.*);
    }
    self.methods.deinit();
}

pub fn getMethod(self: *const Resource, method_name: []const u8) ?Method {
    return self.methods.get(method_name);
}

pub fn callMethod(self: *Resource, editor: *Editor, method_name: []const u8, params: [][]const u8) !void {
    const method = self.methods.get(method_name) orelse return error.MethodNotFound;
    try method(editor, params);
}

pub fn putMethod(self: *Resource, method_name: []const u8, method: Method) !void {
    const result = try self.methods.getOrPut(method_name);
    errdefer if (!result.found_existing) {
        _ = self.methods.remove(method_name);
    };
    if (!result.found_existing) {
        result.key_ptr.* = try self.allocator.dupe(u8, method_name);
    }
    errdefer if (!result.found_existing) {
        self.allocator.free(result.key_ptr.*);
    };
    result.value_ptr.* = method;
}

pub fn removeMethod(self: *Resource, method_name: []const u8) void {
    const entry = self.methods.fetchRemove(method_name) orelse return;
    self.allocator.free(entry.key);
}
