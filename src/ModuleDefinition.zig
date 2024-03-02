const std = @import("std");
const yaml = @import("yaml");

manifest_version: []const u8,
name: []const u8,
description: []const u8,
command: Command,
options: std.StringArrayHashMap(ModuleOption),
yaml: yaml.Yaml,

pub const Command = struct {
    description: []const u8,
    options: std.StringArrayHashMap(OptionArgument),
    positionals: []PositionalArgument,
    subcommands: std.StringArrayHashMap(Command),

    pub fn fromValue(allocator: std.mem.Allocator, value: yaml.Value) !@This() {
        return .{
            .description = value.map.get("description").?.string,
            .options = b: {
                var options = std.StringArrayHashMap(OptionArgument).init(allocator);
                if (value.map.get("options")) |src_options| {
                    var it = src_options.map.iterator();
                    while (it.next()) |src|
                        try options.putNoClobber(src.key_ptr.*, try OptionArgument.fromValue(src.value_ptr.*));
                }
                break :b options;
            },
            .positionals = b: {
                var positionals = std.ArrayList(PositionalArgument).init(allocator);
                if (value.map.get("positionals")) |src_positionals|
                    for (src_positionals.list) |src|
                        try positionals.append(try PositionalArgument.fromValue(src));
                break :b try positionals.toOwnedSlice();
            },
            .subcommands = b: {
                var subcommands = std.StringArrayHashMap(Command).init(allocator);
                if (value.map.get("subcommands")) |src_subcommands| {
                    var it = src_subcommands.map.iterator();
                    while (it.next()) |src|
                        try subcommands.putNoClobber(src.key_ptr.*, try Command.fromValue(allocator, src.value_ptr.*));
                }
                break :b subcommands;
            },
        };
    }
};

pub const ValueType = enum {
    int,
    float,
    str,
    bool_,

    pub fn from(source: []const u8) !@This() {
        return if (std.mem.eql(u8, source, "int"))
            .int
        else if (std.mem.eql(u8, source, "float"))
            .float
        else if (std.mem.eql(u8, source, "string"))
            .str
        else if (std.mem.eql(u8, source, "bool"))
            .bool_
        else
            return error.InvalidYaml;
    }
};

pub const OptionArgument = struct {
    short: ?[]const u8,
    type: ValueType,
    description: []const u8,
    default: DefaultValue,

    pub fn fromValue(value: yaml.Value) !@This() {
        return .{
            .short = value.map.get("short").?.string,
            .type = try ValueType.from(value.map.get("type").?.string),
            .default = try DefaultValue.from(value.map.get("default").?),
            .description = value.map.get("description").?.string,
        };
    }
};

pub const DefaultValue = union(enum) {
    int: i64,
    float: f64,
    str: []const u8,
    bool_: bool,

    pub fn from(source: yaml.Value) !@This() {
        return switch (source) {
            .int => |i| .{ .int = i },
            .float => |f| .{ .float = f },
            .string => |s| .{ .str = s },
            else => return error.InvalidYaml,
        };
    }
};

pub const PositionalArgument = struct {
    name: []const u8,
    type: ValueType,
    description: []const u8,

    pub fn fromValue(value: yaml.Value) !@This() {
        return .{
            .name = value.map.get("name").?.string,
            .description = value.map.get("description").?.string,
            .type = try ValueType.from(value.map.get("type").?.string),
        };
    }
};

pub const ModuleOption = struct {
    type: ValueType,
    description: []const u8,

    pub fn fromValue(value: yaml.Value) !@This() {
        return .{
            .description = value.map.get("description").?.string,
            .type = try ValueType.from(value.map.get("type").?.string),
        };
    }
};

pub fn fromValue(y: *yaml.Yaml, value: yaml.Value) !@This() {
    var definition: @This() = .{
        .yaml = undefined,
        .manifest_version = value.map.get("manifest_version").?.string,
        .name = value.map.get("description").?.string,
        .description = value.map.get("description").?.string,
        .options = b: {
            var options = std.StringArrayHashMap(ModuleOption).init(y.arena.allocator());
            var src_options = value.map.get("options").?.map.iterator();
            while (src_options.next()) |src_option|
                try options.putNoClobber(src_option.key_ptr.*, try ModuleOption.fromValue(src_option.value_ptr.*));
            break :b options;
        },
        .command = try Command.fromValue(y.arena.allocator(), value.map.get("command").?),
    };
    definition.yaml = y.*;
    return definition;
}

pub fn deinit(self: *@This()) void {
    self.yaml.deinit();
}

pub fn parse(allocator: std.mem.Allocator, source: []const u8) !@This() {
    var y = try yaml.Yaml.load(allocator, source);
    errdefer y.deinit();
    return try @This().fromValue(&y, y.docs.items[0]);
}
