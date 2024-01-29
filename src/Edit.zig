const std = @import("std");

const TextRef = @import("TextRef.zig");
const Client = @import("Client.zig");

active_ref: *TextRef,
client: *const Client,

pub fn isCommandLineActive(self: *const @This()) bool {
    return self.active_ref == &self.client.command_line_ref;
}
