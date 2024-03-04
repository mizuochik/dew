const std = @import("std");
const yaml = @import("yaml");

manifest_version: []const u8,
name: []const u8,
description: []const u8,
command: Command,
options: []ModuleOption,
yaml: yaml.Yaml,

pub const Command = struct {
    name: []const u8,
    description: []const u8,
    options: []OptionArgument,
    positionals: []PositionalArgument,
    subcommands: []Command,

    pub fn fromValue(allocator: std.mem.Allocator, value: yaml.Value, module_name: ?[]const u8) !@This() {
        return .{
            .name = module_name orelse value.map.get("name").?.string,
            .description = value.map.get("description").?.string,
            .options = b: {
                var options = std.ArrayList(OptionArgument).init(allocator);
                errdefer options.deinit();
                if (value.map.get("options")) |src_options| {
                    for (src_options.list) |src|
                        try options.append(try OptionArgument.fromValue(src));
                }
                break :b try options.toOwnedSlice();
            },
            .positionals = b: {
                var positionals = std.ArrayList(PositionalArgument).init(allocator);
                if (value.map.get("positionals")) |src_positionals|
                    for (src_positionals.list) |src|
                        try positionals.append(try PositionalArgument.fromValue(src));
                break :b try positionals.toOwnedSlice();
            },
            .subcommands = b: {
                var subcommands = std.ArrayList(Command).init(allocator);
                errdefer subcommands.deinit();
                if (value.map.get("subcommands")) |src_subcommands|
                    for (src_subcommands.list) |src|
                        try subcommands.append(try Command.fromValue(allocator, src, null));
                break :b try subcommands.toOwnedSlice();
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
        else if (std.mem.eql(u8, source, "str"))
            .str
        else if (std.mem.eql(u8, source, "bool"))
            .bool_
        else
            return error.InvalidYaml;
    }
};

pub const OptionArgument = struct {
    long: ?[]const u8,
    short: ?[]const u8,
    type: ValueType,
    description: []const u8,
    default: DefaultValue,

    pub fn fromValue(value: yaml.Value) !@This() {
        const value_type = try ValueType.from(value.map.get("type").?.string);
        return .{
            .long = if (value.map.get("long")) |v|
                v.string
            else
                null,
            .short = if (value.map.get("short")) |v|
                v.string
            else
                null,
            .type = value_type,
            .default = switch (value_type) {
                .bool_ => .{ .bool_ = false },
                else => try DefaultValue.from(value.map.get("default").?),
            },
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

pub fn fromValue(y: *yaml.Yaml, value: yaml.Value) !@This() {
    var definition: @This() = .{
        .yaml = undefined,
        .manifest_version = value.map.get("manifest_version").?.string,
        .name = value.map.get("name").?.string,
        .description = value.map.get("description").?.string,
        .options = b: {
            var options = std.ArrayList(ModuleOption).init(y.arena.allocator());
            errdefer options.deinit();
            if (value.map.get("options")) |src_options|
                for (src_options.list) |src_option|
                    try options.append(try ModuleOption.fromValue(src_option));
            break :b try options.toOwnedSlice();
        },
        .command = try Command.fromValue(y.arena.allocator(), value.map.get("command").?, value.map.get("name").?.string),
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
