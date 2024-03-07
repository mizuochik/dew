const std = @import("std");
const parser = @import("parser.zig");
const ModuleDefinition = @import("ModuleDefinition.zig");
const Command = @import("Command.zig");

pub const Error = error{
    InvalidArgument,
    EndOfInput,
};

const State = struct {
    allocator: std.mem.Allocator,
    arguments: []const []const u8,
    error_message: ?[]const u8 = null,
    pos: usize = 0,

    pub fn deinit(self: *const @This()) void {
        if (self.error_message) |m|
            self.allocator.free(m);
    }
};

pub fn parse(allocator: std.mem.Allocator, definition: ModuleDefinition.Command, input: []const u8) !Command {
    const args = try RawParser.parse(allocator, input);
    defer {
        for (args) |arg|
            std.testing.allocator.free(arg);
        std.testing.allocator.free(args);
    }
    return ArgumentParser.parse(allocator, definition, args);
}

const ArgumentParser = struct {
    fn parse(allocator: std.mem.Allocator, definition: ModuleDefinition.Command, arguments: []const []const u8) !Command {
        var state: State = .{
            .allocator = allocator,
            .arguments = arguments,
        };
        return command(&state, definition);
    }

    fn command(state: *State, definition: ModuleDefinition.Command) !Command {
        const command_name = try stringArgument(state, definition.name);
        errdefer state.allocator.free(command_name);

        var options = try commnadOptions(state);
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

        const positionals = try commandPositionals(state);
        errdefer {
            for (positionals) |positional| {
                switch (positional) {
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
            .positionals = positionals,
            .subcommand = null,
        };
    }

    fn commnadOptions(state: *State) !std.StringArrayHashMap(Command.Value) {
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
        return options;
    }

    fn commandPositionals(state: *State) ![]Command.Value {
        var poss = std.ArrayList(Command.Value).init(state.allocator);
        errdefer {
            for (poss.items) |pos| {
                switch (pos) {
                    .str => |s| state.allocator.free(s),
                    else => {},
                }
            }
            poss.deinit();
        }
        return poss.toOwnedSlice();
    }

    fn stringArgument(state: *State, string: []const u8) ![]const u8 {
        if (state.pos >= state.arguments.len)
            return Error.EndOfInput;
        if (std.mem.eql(u8, state.arguments[state.pos], string))
            return state.allocator.dupe(u8, state.arguments[state.pos]);
        return Error.InvalidArgument;
    }
};

const RawParser = struct {
    fn parse(allocator: std.mem.Allocator, input: []const u8) ![]const []const u8 {
        var state: parser.State = .{
            .allocator = allocator,
            .input = input,
        };
        defer state.deinit();
        return arguments(&state);
    }

    fn arguments(state: *parser.State) ![]const []const u8 {
        var args = std.ArrayList([]const u8).init(state.allocator);
        errdefer {
            for (args.items) |arg| {
                state.allocator.free(arg);
            }
            args.deinit();
        }
        parser.spaces(state) catch {};
        while (true) {
            {
                const arg = try argument(state);
                errdefer state.allocator.free(arg);
                try args.append(arg);
            }
            if (parser.spaces(state)) |_|
                continue
            else |_| if (parser.endOfInput(state)) |_|
                return args.toOwnedSlice()
            else |e|
                return e;
        }
    }

    fn argument(state: *parser.State) ![]const u8 {
        const in = state.input;
        errdefer state.input = in;
        var arg = std.ArrayList(u8).init(state.allocator);
        errdefer arg.deinit();
        const head = try argumentCharacter(state);
        try arg.append(head);
        while (true)
            if (argumentCharacter(state)) |c|
                try arg.append(c)
            else |_|
                return arg.toOwnedSlice();
    }

    fn argumentCharacter(state: *parser.State) !u8 {
        return parser.letter(state) catch parser.digit(state) catch parser.anyCharacter(state, "-_.:/[]{}");
    }
};

test "parse command" {
    var definition = try ModuleDefinition.parse(std.testing.allocator, @embedFile("builtin_modules/cursors.yaml"));
    defer definition.deinit();
    inline for (.{
        .{ .option = "cursor", .given = "cursors --cursor 1 move 10:5", .expected = .{ .name = "cursors", .cursor = "1", .subcommand_name = "move", .target = "10:5" } },
        .{ .option = "c", .given = "cursors -c 1 move 10:5", .expected = .{ .name = "cursors", .cursor = "1", .subcommand_name = "move", .target = "10:5" } },
    }) |case| {
        var actual = try @This().parse(std.testing.allocator, definition.command, case.given);
        defer actual.deinit();
        // try std.testing.expectEqualStrings(case.expected.name, actual.name);
        // try std.testing.expectEqualStrings(case.expected.cursor, actual.options.get(case.option).?.str);
        // try std.testing.expectEqualStrings(case.expected.subcommand_name, actual.subcommand.?.name);
        // try std.testing.expectEqualStrings(case.expected.target, actual.subcommand.?.positionals[0].str);
    }
}
