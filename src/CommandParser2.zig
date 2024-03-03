const std = @import("std");
const parser = @import("parser.zig");
const ModuleDefinition = @import("ModuleDefinition.zig");
const Command = @import("Command.zig");

pub fn parse(allocator: std.mem.Allocator, name: []const u8, definition: ModuleDefinition.Command, input: []const u8) !Command {
    var state: parser.State = .{
        .allocator = allocator,
        .input = input,
    };
    parser.spaces(&state) catch {};
    return command(&state, name, definition);
}

fn command(state: *parser.State, name: []const u8, definition: ModuleDefinition.Command) !Command {
    std.debug.print("# definition = {s}\n", .{name});
    std.debug.print("# state.input = {s}\n", .{state.input});

    const options = try command_options(state, definition);
    errdefer {
        var options_it = options.iterator();
        while (options_it.next()) |option| {
            state.allocator.free(option.key_ptr.*);
            if (option.value_ptr.*) |value| {
                switch (value) {
                    .str => |s| state.allocator.free(s),
                    else => {},
                }
            }
        }
    }

    return .{
        .allocator = state.allocator,
        .name = name,
        .options = options,
        .positionals = undefined,
        .subcommand = null,
    };
}

fn command_options(state: *parser.State, definition: ModuleDefinition.Command) !std.StringArrayHashMap(Command.Value) {
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

    outer: while (true) {
        var option_definitions = definition.options.iterator();
        while (option_definitions.next()) |option_definition| {
            _ = parser.string(state, "--") catch continue;
            const key = try parser.string(state, option_definition.key_ptr.*);
            errdefer state.allocator.free(key);
            switch (option_definition.value_ptr.*.type) {
                .bool_ => {
                    try options.putNoClobber(key, .{ .bool_ = true });
                    continue :outer;
                },
                .int => {
                    const n = try parser.number(state);
                    try options.putNoClobber(key, .{ .int = @intCast(n) });
                    continue :outer;
                },
                .str => {
                    std.debug.print("# parse str option: input = {s}, key = {s}\n", .{ state.input, option_definition.key_ptr.* });

                    const s = try argument(state);
                    errdefer state.allocator.free(s);
                    try options.putNoClobber(key, .{ .str = s });
                    continue :outer;
                },
                else => unreachable,
            }
        }
        break;
    }

    return options;
}

fn command_option_key(state: *parser.State) ![]const u8 {
    _ = state;
    return undefined;
}

fn argument(state: *parser.State) ![]const u8 {
    const in = state.input;
    errdefer state.input = in;
    var cs = std.ArrayList(u8).init(state.allocator);
    errdefer cs.deinit();
    const head = try nameCharacter(state);
    try cs.append(head);
    while (nameCharacter(state)) |c|
        try cs.append(c)
    else |_|
        return cs.toOwnedSlice();
}

fn nameCharacter(state: *parser.State) !u8 {
    return parser.letter(state) catch parser.digit(state) catch parser.anyCharacter(state, "-_./[]{}");
}

test "parse command" {
    var definition = try ModuleDefinition.parse(std.testing.allocator, @embedFile("builtin_modules/cursors.yaml"));
    errdefer definition.deinit();

    var actual = try @This().parse(std.testing.allocator, definition.name, definition.command, "cursors --cursor 1 move --select 10:5");
    errdefer actual.deinit();

    try std.testing.expectEqualStrings("cursors", actual.name);
    try std.testing.expectFmt("1", "{}", .{actual.options.get("cursor").?});
}
