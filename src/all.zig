const std = @import("std");

test {
    _ = std.testing.refAllDeclsRecursive(struct {
        pub const Editor = @import("Editor.zig");
        pub const Display = @import("Display.zig");
        pub const Terminal = @import("Terminal.zig");
        pub const Client = @import("Client.zig");
        pub const TextRef = @import("TextRef.zig");
        pub const Resource = @import("Resource.zig");
        pub const CommandParser = @import("CommandParser.zig");
        pub const ResourceRegistry = @import("ResourceRegistry.zig");
        pub const CommandEvaluator = @import("CommandEvaluator.zig");
        pub const KeyEvaluator = @import("KeyEvaluator.zig");
        pub const Module = @import("Module.zig");
        pub const keyboard = @import("keyboard.zig");
        pub const Position = @import("Position.zig");
        pub const ModuleDefinition = @import("ModuleDefinition.zig");
        pub const builtin_resources = @import("builtin_resources.zig");
        pub const builtin_modules = @import("builtin_modules.zig");
        pub const parser = @import("parser.zig");
        pub const e2e = @import("e2e.zig");
    });
}
