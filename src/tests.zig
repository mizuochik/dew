const std = @import("std");

test {
    _ = std.testing.refAllDeclsRecursive(struct {
        pub const Editor = @import("Editor.zig");
        pub const Display = @import("Display.zig");
        pub const Terminal = @import("Terminal.zig");
        pub const Client = @import("Client.zig");
        pub const Resource = @import("Resource.zig");
        pub const MethodParser = @import("MethodParser.zig");
        pub const ResourceRegistry = @import("MethodParser.zig");
        pub const MethodEvaluator = @import("MethodEvaluator.zig");
        pub const KeyEvaluator = @import("KeyEvaluator.zig");
        pub const keyboard = @import("keyboard.zig");
        pub const builtin_resources = @import("builtin_resources.zig");
        pub const e2e = @import("e2e.zig");
    });
}
