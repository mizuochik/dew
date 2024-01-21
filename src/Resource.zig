const std = @import("std");
const Editor = @import("Editor.zig");

pub const Method = *const fn (editor: *Editor, arguments: [][]const u8) anyerror!void;

allocator: std.mem.Allocator,
editor: *Editor,
methods: std.StringHashMap(Method),

pub fn init(allocator: std.mem.Allocator, editor: *Editor) @This() {
    return .{
        .allocator = allocator,
        .editor = editor,
        .methods = std.StringHashMap(Method).init(allocator),
    };
}

pub fn deinit(self: *@This()) void {
    var keys = self.methods.keyIterator();
    while (keys.next()) |key| {
        self.removeMethod(key.*);
    }
    self.methods.deinit();
}

pub fn callMethod(self: *@This(), method_name: []const u8, arguments: [][]const u8) !void {
    const method = self.methods.get(method_name) orelse return error.MethodNotFound;
    try method(self.editor, arguments);
}

pub fn putMethod(self: *@This(), method_name: []const u8, method: Method) !void {
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

pub fn removeMethod(self: *@This(), method_name: []const u8) void {
    const entry = self.methods.fetchRemove(method_name) orelse return;
    self.allocator.free(entry.key);
}
