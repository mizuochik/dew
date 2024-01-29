const Text = @import("Text.zig");
const Cursor = @import("Cursor.zig");

text: *Text,
cursor: Cursor,
y_scroll: usize = 0,

pub fn init(text: *Text) @This() {
    return .{
        .text = text,
        .cursor = .{
            .text = text,
        },
    };
}
