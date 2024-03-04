const std = @import("std");
const parser = @import("parser.zig");
const ModuleDefinition = @import("ModuleDefinition.zig");
const Command = @import("Command.zig");

pub fn parse(allocator: std.mem.Allocator, definition: ModuleDefinition.Command, input: []const u8) !Command {
    var state: parser.State = .{
        .allocator = allocator,
        .input = input,
    };
    parser.spaces(&state) catch {};
    return command(&state, definition);
}

fn command(state: *parser.State, definition: ModuleDefinition.Command) !Command {
    const command_name = try parser.string(state, definition.name);
    errdefer state.allocator.free(command_name);

    _ = try parser.spaces(state);

    const options = try commandOptions(state, definition);
    errdefer {
        var options_it = options.iterator();
        while (options_it.next()) |option| {
            state.allocator.free(option.key_ptr.*);
            switch (option.value_ptr.*) {
                .str => |s| state.allocator.free(s),
                else => {},
            }
        }
    }

    var positionals = std.ArrayList(Command.Value).init(state.allocator);
    errdefer {
        for (positionals.items) |value| {
            switch (value) {
                .str => |s| state.allocator.free(s),
                else => {},
            }
        }
        positionals.deinit();
    }

    return .{
        .allocator = state.allocator,
        .name = command_name,
        .options = options,
        .positionals = try positionals.toOwnedSlice(),
        .subcommand = null,
    };
}

fn commandOptions(state: *parser.State, definition: ModuleDefinition.Command) !std.StringArrayHashMap(Command.Value) {
    const in = state.input;
    errdefer state.input = in;

    var options = std.StringArrayHashMap(Command.Value).init(state.allocator);
    errdefer {
        var options_it = options.iterator();
        while (options_it.next()) |option| {
            state.allocator.free(option.key_ptr.*);
            switch (option.value_ptr.*) {
                .str => |s| state.allocator.free(s),
                else => {},
            }
        }
        options.deinit();
    }

    while (true) {
        const before = state.input;
        for (definition.options) |option_definition| {
            if (option_definition.long) |long| {
                if (longOption(state, option_definition)) |value| {
                    const key = try state.allocator.dupe(u8, long);
                    errdefer state.allocator.free(key);
                    try options.putNoClobber(key, value);
                    _ = parser.spaces(state) catch
                        try parser.endOfInput(state);
                } else |_| {}
            }
            if (option_definition.short) |short| {
                if (shortOption(state, option_definition)) |value| {
                    const key = try state.allocator.dupe(u8, short);
                    errdefer state.allocator.free(key);
                    try options.putNoClobber(key, value);
                    _ = parser.spaces(state) catch
                        try parser.endOfInput(state);
                } else |_| {}
            }
        }
        if (before.ptr == state.input.ptr)
            break;
    }

    return options;
}

fn longOption(state: *parser.State, definition: ModuleDefinition.OptionArgument) !Command.Value {
    const in = state.input;
    errdefer state.input = in;
    const dash = try parser.string(state, "--");
    state.allocator.free(dash);
    const name = try parser.string(state, definition.long.?);
    state.allocator.free(name);
    _ = parser.spaces(state) catch
        try parser.character(state, '=');
    return typedValue(state, definition.type);
}

fn shortOption(state: *parser.State, definition: ModuleDefinition.OptionArgument) !Command.Value {
    const in = state.input;
    errdefer state.input = in;
    _ = try parser.character(state, '-');
    const name = try parser.string(state, definition.short.?);
    state.allocator.free(name);
    _ = parser.spaces(state) catch {}; // Allow no space
    return typedValue(state, definition.type);
}

fn typedValue(state: *parser.State, value_type: ModuleDefinition.ValueType) !Command.Value {
    const in = state.input;
    errdefer state.input = in;
    switch (value_type) {
        .bool_ => return .{ .bool_ = true },
        .int => {
            const n = try parser.number(state);
            return .{ .int = @intCast(n) };
        },
        .str => {
            var cs = std.ArrayList(u8).init(state.allocator);
            errdefer cs.deinit();
            const head = try nameCharacter(state);
            try cs.append(head);
            while (nameCharacter(state)) |c|
                try cs.append(c)
            else |_|
                return .{
                    .str = try cs.toOwnedSlice(),
                };
        },
        else => unreachable,
    }
}

fn nameCharacter(state: *parser.State) !u8 {
    return parser.letter(state) catch parser.digit(state) catch parser.anyCharacter(state, "-_./[]{}");
}

test "parse command" {
    var definition = try ModuleDefinition.parse(std.testing.allocator, @embedFile("builtin_modules/cursors.yaml"));
    defer definition.deinit();
    inline for (.{
        .{ .option = "cursor", .given = "cursors --cursor 1 move 10:5", .expected = .{ .name = "cursors", .cursor = "1" } },
        .{ .option = "c", .given = "cursors -c 1 move 10:5", .expected = .{ .name = "cursors", .cursor = "1" } },
    }) |case| {
        var actual = try @This().parse(std.testing.allocator, definition.command, case.given);
        defer actual.deinit();
        try std.testing.expectEqualStrings(case.expected.name, actual.name);
        try std.testing.expectEqualStrings(case.expected.cursor, actual.options.get(case.option).?.str);
    }
}
