const std = @import("std");

test {
    _ = std.testing.refAllDeclsRecursive(struct {
        pub const Editor = @import("Editor.zig");
        pub const Display = @import("Display.zig");
        pub const Terminal = @import("Terminal.zig");
        pub const Client = @import("Client.zig");
        pub const CommandParser = @import("CommandParser.zig");
        pub const ResourceRegistry = @import("CommandParser.zig");
        pub const MethodEvaluator = @import("MethodEvaluator.zig");
        pub const keyboard = @import("keyboard.zig");
        pub const e2e = @import("e2e.zig");
    });
}
