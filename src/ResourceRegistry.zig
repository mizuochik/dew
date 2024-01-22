const std = @import("std");
const builtin_commands = @import("builtin_commands.zig");
const Editor = @import("Editor.zig");
const Resource = @import("Resource.zig");

const Command = *const fn (editor: *Editor, arguments: [][]const u8) anyerror!void;

allocator: std.mem.Allocator,
resources: std.StringHashMap(Resource),

pub fn init(allocator: std.mem.Allocator) @This() {
    return .{
        .allocator = allocator,
        .resources = std.StringHashMap(Resource).init(allocator),
    };
}

pub fn get(self: *const @This(), name: []const u8) !Resource.Method {
    var it = std.mem.split(u8, name, ".");
    const resource_name = it.next() orelse return error.InvalidMethod;
    const method_name = it.next() orelse return error.InvalidMethod;
    const resource = self.resources.get(resource_name) orelse return error.ResourceNotFound;
    return resource.getMethod(method_name) orelse error.MethodNotFound;
}

pub fn registerBuiltinResources(self: *@This()) !void {
    var files = Resource.init(self.allocator);
    errdefer files.deinit();
    try files.putMethod("open", builtin_commands.open_file);
    try files.putMethod("new", builtin_commands.new_file);
    try files.putMethod("save", builtin_commands.save_file);
    try self.resources.putNoClobber("files", files);
    errdefer self.resources.remove("files");
}

pub fn deinit(self: *@This()) void {
    var methods = self.resources.valueIterator();
    while (methods.next()) |method| {
        method.deinit();
    }
    self.resources.deinit();
}
