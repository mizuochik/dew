const std = @import("std");

pub const Editor = @import("dew/Editor.zig");
pub const UnicodeString = @import("dew/UnicodeString.zig");
pub const Buffer = @import("dew/Buffer.zig");
pub const View = @import("dew/View.zig");
pub const BufferView = @import("dew/BufferView.zig");
pub const Position = @import("dew/Position.zig");
pub const Reader = @import("dew/Reader.zig");
const keyboard = @import("dew/keyboard.zig");
pub const Keyboard = keyboard.Keyboard;
pub const Key = keyboard.Key;
pub const Arrow = keyboard.Arrow;
pub const c = @import("dew/c.zig");

test {
    std.testing.refAllDecls(@This());
}
