const std = @import("std");

pub const EditorController = @import("controllers/EditorController.zig");

test {
    std.testing.refAllDecls(@This());
}
