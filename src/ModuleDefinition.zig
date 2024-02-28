manifest_version: []const u8,
name: []const u8,
description: []const u8,
command: Command,
options: []ModuleOption,

pub const Command = struct {
    options: ?[]OptionArgument,
    positionals: ?[]PositionalArgument,
    subcommands: ?[]SubcommandArgument,
};

pub const OptionArgument = struct {
    short: ?[]const u8,
    long: ?[]const u8,
    type: []const u8,
    description: []const u8,
    default: union(enum) {
        int: i32,
        float: f64,
        str: []const u8,
        bool_: bool,
    },
};

pub const PositionalArgument = struct {
    name: []const u8,
    type: []const u8,
    description: []const u8,
};

pub const SubcommandArgument = struct {
    name: []const u8,
    description: []const u8,
    options: ?[]OptionArgument,
    positionals: ?[]PositionalArgument,
    subcommands: ?[]SubcommandArgument,
};

pub const ModuleOption = struct {
    key: []const u8,
    type: []const u8,
    description: []const u8,
};
