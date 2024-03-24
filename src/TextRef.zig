const TextRef = @This();
const Text = @import("Text.zig");
const Selection = @import("Selection.zig");

text: *Text,
selection: Selection,
y_scroll: usize = 0,

pub fn init(text: *Text) TextRef {
    return .{
        .text = text,
        .selection = .{
            .text = text,
        },
    };
}
