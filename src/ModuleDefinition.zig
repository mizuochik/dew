const ModuleDefinition = @This();
const std = @import("std");
const c = @import("c.zig");

arena: std.heap.ArenaAllocator,
manifest_version: []const u8,
name: []const u8,
description: []const u8,
command: Command,
options: []const ModuleOption = &[_]ModuleOption{},

pub const Command = struct {
    name: []const u8,
    description: []const u8,
    options: []const OptionArgument = &[_]OptionArgument{},
    positionals: []const PositionalArgument = &[_]PositionalArgument{},
    subcommands: []const Command = &[_]Command{},
};

pub const ValueType = enum {
    int,
    float,
    str,
    bool,
};

pub const OptionArgument = struct {
    long: ?[]const u8 = null,
    short: ?[]const u8 = null,
    type: ValueType,
    description: []const u8,
    default: ?DefaultValue = null,
};

pub const DefaultValue = union(enum) {
    int: i64,
    float: f64,
    str: []const u8,
    bool_: bool,
};

pub const PositionalArgument = struct {
    name: []const u8,
    type: ValueType,
    description: []const u8,
};

pub const ModuleOption = struct {
    name: []const u8,
    type: ValueType,
    description: []const u8,
    default: DefaultValue,
};

pub fn deinit(self: *ModuleDefinition) void {
    self.arena.deinit();
}

pub fn parse(allocator: std.mem.Allocator, source: []const u8) !ModuleDefinition {
    var parser = try Parser.init(allocator, source);
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
        var command_: ?Command = null;
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
                else if (std.mem.eql(u8, key, "command"))
                    command_ = try self.command(name orelse return Error.UnexpectedInput)
                else {
                    break;
                }
                continue;
            }
            break;
        }
        if (command_) |*cmd|
            cmd.name = name orelse return Error.UnexpectedInput;
        return .{
            .arena = self.arena,
            .manifest_version = manifest_version orelse return Error.UnexpectedInput,
            .name = name orelse return Error.UnexpectedInput,
            .description = description orelse return Error.UnexpectedInput,
            .command = command_ orelse return Error.UnexpectedInput,
            .options = module_options orelse return Error.UnexpectedInput,
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
            .type = type_ orelse return Error.UnexpectedInput,
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
            .bool
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

    fn command(self: *Parser, module_name: ?[]const u8) !Command {
        if (module_name) |_| {
            var event: c.yaml_event_s = undefined;
            if (c.yaml_parser_parse(&self.yaml_parser, &event) != 1)
                return Error.YamlParseError;
            defer c.yaml_event_delete(&event);
            if (event.type != c.YAML_MAPPING_START_EVENT)
                return Error.UnexpectedInput;
        }
        var description: ?[]const u8 = null;
        var options: ?[]OptionArgument = null;
        var positionals: ?[]PositionalArgument = null;
        var name: ?[]const u8 = module_name;
        var subcommands_: ?[]Command = null;
        while (true) {
            var event: c.yaml_event_s = undefined;
            if (c.yaml_parser_parse(&self.yaml_parser, &event) != 1)
                return Error.YamlParseError;
            defer c.yaml_event_delete(&event);
            if (event.type == c.YAML_MAPPING_END_EVENT)
                break;
            if (event.type == c.YAML_SCALAR_EVENT) {
                const key = event.data.scalar.value[0..event.data.scalar.length];
                if (std.mem.eql(u8, key, "name")) {
                    if (module_name) |_|
                        return Error.UnexpectedInput;
                    name = try self.scalarString();
                } else if (std.mem.eql(u8, key, "description"))
                    description = try self.scalarString()
                else if (std.mem.eql(u8, key, "options"))
                    options = try self.optionArguments()
                else if (std.mem.eql(u8, key, "subcommands"))
                    subcommands_ = try self.subcommands()
                else if (std.mem.eql(u8, key, "positionals"))
                    positionals = try self.positionalArguments()
                else
                    unreachable;
                continue;
            }
            return Error.UnexpectedInput;
        }
        return .{
            .name = name orelse return Error.UnexpectedInput,
            .description = description orelse return Error.UnexpectedInput,
            .options = options orelse try self.arena.allocator().alloc(OptionArgument, 0),
            .positionals = positionals orelse try self.arena.allocator().alloc(PositionalArgument, 0),
            .subcommands = subcommands_ orelse try self.arena.allocator().alloc(Command, 0),
        };
    }

    fn optionArguments(self: *Parser) ![]OptionArgument {
        {
            var event: c.yaml_event_s = undefined;
            if (c.yaml_parser_parse(&self.yaml_parser, &event) != 1)
                return Error.YamlParseError;
            defer c.yaml_event_delete(&event);
            if (event.type != c.YAML_SEQUENCE_START_EVENT)
                return Error.UnexpectedInput;
        }
        var arguments = std.ArrayList(OptionArgument).init(self.arena.allocator());
        while (true) {
            var event: c.yaml_event_s = undefined;
            if (c.yaml_parser_parse(&self.yaml_parser, &event) != 1)
                return Error.YamlParseError;
            defer c.yaml_event_delete(&event);
            if (event.type == c.YAML_SEQUENCE_END_EVENT)
                break;
            if (event.type == c.YAML_MAPPING_START_EVENT)
                try arguments.append(try self.optionArgument());
        }
        return try arguments.toOwnedSlice();
    }

    fn optionArgument(self: *Parser) !OptionArgument {
        var long: ?[]const u8 = null;
        var short: ?[]const u8 = null;
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
                if (std.mem.eql(u8, key, "long"))
                    long = try self.scalarString()
                else if (std.mem.eql(u8, key, "short"))
                    short = try self.scalarString()
                else if (std.mem.eql(u8, key, "type"))
                    type_ = try self.valueType()
                else if (std.mem.eql(u8, key, "description"))
                    description = try self.scalarString()
                else if (std.mem.eql(u8, key, "default"))
                    default = try self.defaultValue()
                else
                    return Error.UnexpectedInput;
                continue;
            }
            return Error.UnexpectedInput;
        }
        return .{
            .long = long,
            .short = short,
            .type = type_ orelse return Error.UnexpectedInput,
            .description = description orelse return Error.UnexpectedInput,
            .default = default,
        };
    }

    fn positionalArguments(self: *Parser) ![]PositionalArgument {
        {
            var event: c.yaml_event_s = undefined;
            if (c.yaml_parser_parse(&self.yaml_parser, &event) != 1)
                return Error.YamlParseError;
            defer c.yaml_event_delete(&event);
            if (event.type != c.YAML_SEQUENCE_START_EVENT)
                return Error.UnexpectedInput;
        }
        var arguments = std.ArrayList(PositionalArgument).init(self.arena.allocator());
        while (true) {
            var event: c.yaml_event_s = undefined;
            if (c.yaml_parser_parse(&self.yaml_parser, &event) != 1)
                return Error.YamlParseError;
            defer c.yaml_event_delete(&event);
            if (event.type == c.YAML_SEQUENCE_END_EVENT)
                break;
            if (event.type == c.YAML_MAPPING_START_EVENT)
                try arguments.append(try self.positionalArgument());
        }
        return try arguments.toOwnedSlice();
    }

    fn positionalArgument(self: *Parser) !PositionalArgument {
        var name: ?[]const u8 = null;
        var type_: ?ValueType = null;
        var description: ?[]const u8 = null;
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
                else
                    return Error.UnexpectedInput;
                continue;
            }
            return Error.UnexpectedInput;
        }
        return .{
            .name = name orelse return Error.UnexpectedInput,
            .type = type_ orelse return Error.UnexpectedInput,
            .description = description orelse return Error.UnexpectedInput,
        };
    }

    fn subcommands(self: *Parser) anyerror![]Command {
        {
            var event: c.yaml_event_s = undefined;
            if (c.yaml_parser_parse(&self.yaml_parser, &event) != 1)
                return Error.YamlParseError;
            defer c.yaml_event_delete(&event);
            if (event.type != c.YAML_SEQUENCE_START_EVENT)
                return Error.UnexpectedInput;
        }
        var commands = std.ArrayList(Command).init(self.arena.allocator());
        while (true) {
            var event: c.yaml_event_s = undefined;
            if (c.yaml_parser_parse(&self.yaml_parser, &event) != 1)
                return Error.YamlParseError;
            defer c.yaml_event_delete(&event);
            if (event.type == c.YAML_SEQUENCE_END_EVENT)
                break;
            if (event.type == c.YAML_MAPPING_START_EVENT)
                try commands.append(try self.command(null));
        }
        return try commands.toOwnedSlice();
    }
};

test "parseByLibYaml" {
    var actual = try ModuleDefinition.parse(std.testing.allocator, @embedFile("builtin_modules/selections.yaml"));
    defer actual.deinit();
    try std.testing.expectEqualDeep(ModuleDefinition{
        .arena = actual.arena,
        .manifest_version = "0.1",
        .name = "selections",
        .description = "Selections in an editor",
        .options = &[_]ModuleOption{
            .{
                .name = "hello",
                .type = .str,
                .description = "foo",
                .default = .{ .str = "*" },
            },
        },
        .command = .{
            .name = "selections",
            .description = "Control selections",
            .options = &[_]OptionArgument{},
            .positionals = &[_]PositionalArgument{},
            .subcommands = &[_]Command{
                .{
                    .name = "list",
                    .description = "List selection infos",
                },
                .{
                    .name = "get",
                    .description = "Get selection info",
                    .positionals = &[_]PositionalArgument{
                        .{
                            .name = "index",
                            .type = .int,
                            .description = "Selection index",
                        },
                    },
                },
                .{
                    .name = "move",
                    .description = "Move a selection",
                    .options = &[_]OptionArgument{
                        .{
                            .long = "cursor",
                            .type = .bool,
                            .description = "Move cursor of the selection",
                        },
                        .{
                            .long = "anchor",
                            .type = .bool,
                            .description = "Move anchor of the selection",
                        },
                    },
                    .positionals = &[_]PositionalArgument{
                        .{
                            .name = "index",
                            .type = .int,
                            .description = "Selection index",
                        },
                        .{
                            .name = "position",
                            .type = .str,
                            .description = "Target position",
                        },
                    },
                },
            },
        },
    }, actual);
}
