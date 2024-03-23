const std = @import("std");
const yaml = @import("yaml");
const c = @import("c.zig");
const ModuleDefinition = @This();

arena: std.heap.ArenaAllocator,
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
        const options = b: {
            var options_al = std.ArrayList(OptionArgument).init(allocator);
            errdefer options_al.deinit();
            if (value.map.get("options")) |src_options| {
                for (src_options.list) |src|
                    try options_al.append(try OptionArgument.fromValue(src));
            }
            break :b try options_al.toOwnedSlice();
        };
        errdefer allocator.free(options);
        const positionals = b: {
            var positionals = std.ArrayList(PositionalArgument).init(allocator);
            if (value.map.get("positionals")) |src_positionals|
                for (src_positionals.list) |src|
                    try positionals.append(try PositionalArgument.fromValue(src));
            break :b try positionals.toOwnedSlice();
        };
        errdefer allocator.free(positionals);
        const subcommands = b: {
            var subcommands = std.ArrayList(Command).init(allocator);
            errdefer subcommands.deinit();
            if (value.map.get("subcommands")) |src_subcommands|
                for (src_subcommands.list) |src|
                    try subcommands.append(try Command.fromValue(allocator, src, null));
            break :b try subcommands.toOwnedSlice();
        };
        errdefer allocator.free(subcommands);
        return .{
            .name = module_name orelse value.map.get("name").?.string,
            .description = value.map.get("description").?.string,
            .options = options,
            .positionals = positionals,
            .subcommands = subcommands,
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
    type_: ValueType,
    description: []const u8,
    default: DefaultValue,

    pub fn fromValue(value: yaml.Value) !@This() {
        return .{
            .name = value.map.get("name").?.string,
            .description = value.map.get("description").?.string,
            .type_ = try ValueType.from(value.map.get("type").?.string),
            .default = undefined,
        };
    }
};

pub fn fromValue(y: *yaml.Yaml, value: yaml.Value) !@This() {
    var definition: @This() = .{
        .arena = undefined,
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
    self.arena.deinit();
}

pub fn parse(allocator: std.mem.Allocator, source: []const u8) !@This() {
    var y = try yaml.Yaml.load(allocator, source);
    errdefer y.deinit();
    return try @This().fromValue(&y, y.docs.items[0]);
}

pub fn parseByLibYaml(allocator: std.mem.Allocator, source: []const u8) !ModuleDefinition {
    var parser = try Parser.init(allocator, source);
    defer parser.deinit();
    return parser.moduleDefinition();
}

const Parser = struct {
    const Error = error{
        UnexpectedInput,
        YamlParseError,
    };

    arena: std.heap.ArenaAllocator,
    yaml_parser: c.yaml_parser_t,

    fn init(allocator: std.mem.Allocator, input: []const u8) !Parser {
        var parser: c.yaml_parser_t = undefined;
        _ = c.yaml_parser_initialize(&parser);
        errdefer c.yaml_parser_delete(&parser);
        c.yaml_parser_set_input_string(&parser, @ptrCast(input), input.len);
        return .{
            .arena = std.heap.ArenaAllocator.init(allocator),
            .yaml_parser = parser,
        };
    }

    fn deinit(self: *Parser) void {
        c.yaml_parser_delete(&self.yaml_parser);
    }

    fn moduleDefinition(self: *Parser) !ModuleDefinition {
        errdefer self.arena.deinit();

        var manifest_version: ?[]const u8 = null;
        var name: ?[]const u8 = null;
        var description: ?[]const u8 = null;
        var module_options: ?[]ModuleOption = null;
        {
            var event: c.yaml_event_s = undefined;
            if (c.yaml_parser_parse(&self.yaml_parser, &event) != 1)
                return Error.YamlParseError;
            defer c.yaml_event_delete(&event);
            if (event.type != c.YAML_STREAM_START_EVENT)
                return Error.UnexpectedInput;
        }
        {
            var event: c.yaml_event_s = undefined;
            if (c.yaml_parser_parse(&self.yaml_parser, &event) != 1)
                return Error.YamlParseError;
            defer c.yaml_event_delete(&event);
            if (event.type != c.YAML_DOCUMENT_START_EVENT)
                return Error.UnexpectedInput;
        }
        {
            var event: c.yaml_event_s = undefined;
            if (c.yaml_parser_parse(&self.yaml_parser, &event) != 1)
                return Error.YamlParseError;
            defer c.yaml_event_delete(&event);
            if (event.type != c.YAML_MAPPING_START_EVENT)
                return Error.UnexpectedInput;
        }

        while (true) {
            var event: c.yaml_event_s = undefined;
            if (c.yaml_parser_parse(&self.yaml_parser, &event) != 1)
                return Error.YamlParseError;
            defer c.yaml_event_delete(&event);
            if (event.type == c.YAML_MAPPING_END_EVENT)
                break;
            if (event.type == c.YAML_SCALAR_EVENT) {
                const key = event.data.scalar.value[0..event.data.scalar.length];
                if (std.mem.eql(u8, key, "manifest_version"))
                    manifest_version = try self.scalarString()
                else if (std.mem.eql(u8, key, "name"))
                    name = try self.scalarString()
                else if (std.mem.eql(u8, key, "description"))
                    description = try self.scalarString()
                else if (std.mem.eql(u8, key, "options"))
                    module_options = try self.moduleOptions()
                else {
                    break;
                }
                continue;
            }
            break;
        }

        return .{
            .arena = self.arena,
            .manifest_version = manifest_version orelse unreachable,
            .name = name orelse unreachable,
            .description = description orelse unreachable,
            .command = undefined,
            .options = module_options orelse unreachable,
            .yaml = undefined,
        };
    }

    fn moduleOptions(self: *Parser) ![]ModuleOption {
        {
            var event: c.yaml_event_s = undefined;
            if (c.yaml_parser_parse(&self.yaml_parser, &event) != 1)
                return Error.YamlParseError;
            defer c.yaml_event_delete(&event);
            if (event.type != c.YAML_SEQUENCE_START_EVENT)
                return Error.UnexpectedInput;
        }
        var options = std.ArrayList(ModuleOption).init(self.arena.allocator());
        while (true) {
            var event: c.yaml_event_s = undefined;
            if (c.yaml_parser_parse(&self.yaml_parser, &event) != 1)
                return Error.YamlParseError;
            defer c.yaml_event_delete(&event);
            if (event.type == c.YAML_SEQUENCE_END_EVENT) {
                break;
            }
            if (event.type == c.YAML_MAPPING_START_EVENT) {
                try options.append(try self.moduleOption());
            }
        }
        return options.toOwnedSlice();
    }

    fn moduleOption(self: *Parser) !ModuleOption {
        var name: ?[]const u8 = null;
        var type_: ?ValueType = null;
        var description: ?[]const u8 = null;
        var default: ?DefaultValue = null;
        while (true) {
            var event: c.yaml_event_s = undefined;
            if (c.yaml_parser_parse(&self.yaml_parser, &event) != 1)
                return Error.YamlParseError;
            defer c.yaml_event_delete(&event);
            if (event.type == c.YAML_MAPPING_END_EVENT)
                break;
            if (event.type == c.YAML_SCALAR_EVENT) {
                const key = event.data.scalar.value[0..event.data.scalar.length];
                if (std.mem.eql(u8, key, "name"))
                    name = try self.scalarString()
                else if (std.mem.eql(u8, key, "type"))
                    type_ = try self.valueType()
                else if (std.mem.eql(u8, key, "description"))
                    description = try self.scalarString()
                else if (std.mem.eql(u8, key, "default")) {
                    default = try self.defaultValue();
                } else return Error.UnexpectedInput;
                continue;
            }
        }
        return .{
            .name = name orelse return Error.UnexpectedInput,
            .type_ = type_ orelse return Error.UnexpectedInput,
            .description = description orelse return Error.UnexpectedInput,
            .default = default orelse return Error.UnexpectedInput,
        };
    }

    fn scalarString(self: *Parser) ![]const u8 {
        var event: c.yaml_event_s = undefined;
        if (c.yaml_parser_parse(&self.yaml_parser, &event) != 1)
            return Error.YamlParseError;
        defer c.yaml_event_delete(&event);
        if (event.type != c.YAML_SCALAR_EVENT)
            return Error.UnexpectedInput;
        return self.arena.allocator().dupe(u8, event.data.scalar.value[0..event.data.scalar.length]);
    }

    fn valueType(self: *Parser) !ValueType {
        const s = try self.scalarString();
        return if (std.mem.eql(u8, s, "int"))
            .int
        else if (std.mem.eql(u8, s, "float"))
            .float
        else if (std.mem.eql(u8, s, "str"))
            .str
        else if (std.mem.eql(u8, s, "bool"))
            .bool_
        else
            Error.UnexpectedInput;
    }

    fn defaultValue(self: *Parser) !DefaultValue {
        var event: c.yaml_event_s = undefined;
        if (c.yaml_parser_parse(&self.yaml_parser, &event) != 1)
            return Error.YamlParseError;
        defer c.yaml_event_delete(&event);
        if (event.type != c.YAML_SCALAR_EVENT)
            return Error.UnexpectedInput;
        const source = event.data.scalar.value[0..event.data.scalar.length];
        return if (std.fmt.parseInt(i32, source, 10)) |i|
            .{ .int = i }
        else |_| if (std.fmt.parseFloat(f64, source)) |f|
            .{ .float = f }
        else |_|
            .{ .str = try self.arena.allocator().dupe(u8, source) };
    }
};
