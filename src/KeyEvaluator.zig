const std = @import("std");
const Keyboard = @import("Keyboard.zig");
const ResourceRegistry = @import("ResourceRegistry.zig");
const UnicodeString = @import("UnicodeString.zig");

allocator: std.mem.Allocator,
key_map: std.StringHashMap([][]const u8), // Key Name -> Method Lines

pub fn init(allocator: std.mem.Allocator) @This() {
    return .{
        .allocator = allocator,
        .key_map = std.StringHashMap([][]const u8).init(allocator),
    };
}

pub fn deinit(self: *@This()) void {
    var it = self.key_map.iterator();
    while (it.next()) |entry| {
        self.allocator.free(entry.key_ptr.*);
        for (0..entry.value_ptr.len) |i| {
            self.allocator.free(entry.value_ptr.*[i]);
        }
        self.allocator.free(entry.value_ptr.*);
    }
    self.key_map.deinit();
}

pub fn evaluate(self: *@This(), key: Keyboard.Key) ![][]const u8 {
    const key_name = try key.toName(self.allocator);
    defer self.allocator.free(key_name);
    return self.key_map.get(key_name) orelse error.NoKeyMap;
}

pub fn installDefaultKeyMap(self: *@This()) !void {
    try self.putBuiltinKeyMap("C+q", .{"editor.quit"});
    try self.putBuiltinKeyMap("C+f", .{"cursors.move-to forward-character"});
    try self.putBuiltinKeyMap("C+b", .{"cursors.move-to backward-character"});
    try self.putBuiltinKeyMap("C+p", .{"cursors.move-to previous-line"});
    try self.putBuiltinKeyMap("C+n", .{"cursors.move-to next-line"});
    try self.putBuiltinKeyMap("right", .{"cursors.move-to forward-character"});
    try self.putBuiltinKeyMap("left", .{"cursors.move-to backward-character"});
    try self.putBuiltinKeyMap("up", .{"cursors.move-to previous-line"});
    try self.putBuiltinKeyMap("down", .{"cursors.move-to next-line"});
    try self.putBuiltinKeyMap("C+a", .{"cursors.move-to beginning-of-line"});
    try self.putBuiltinKeyMap("C+e", .{"cursors.move-to end-of-line"});
    try self.putBuiltinKeyMap("C+v", .{"view.scroll . down"});
    try self.putBuiltinKeyMap("A+v", .{"view.scroll . up"});
    try self.putBuiltinKeyMap("C+k", .{"text.kill-line"});
    try self.putBuiltinKeyMap("C+m", .{"text.break-line"});
    try self.putBuiltinKeyMap("C+j", .{"text.join-lines"});
    try self.putBuiltinKeyMap("C+d", .{"text.delete-character"});
    try self.putBuiltinKeyMap("C+h", .{"text.delete-backward-character"});
    try self.putBuiltinKeyMap("del", .{"text.delete-backward-character"});
    try self.putBuiltinKeyMap("C+s", .{"files.save"});
}

pub fn putBuiltinKeyMap(self: *@This(), key_name: []const u8, commands: anytype) !void {
    var buf: [4][]const u8 = undefined;
    inline for (commands, 0..) |command, i| {
        buf[i] = command;
    }
    try self.putKeyMap(key_name, buf[0..commands.len]);
}

pub fn putKeyMap(self: *@This(), key_name: []const u8, command_lines: [][]const u8) !void {
    const result = try self.key_map.getOrPut(key_name);
    if (!result.found_existing) {
        const key = try self.allocator.dupe(u8, key_name);
        result.key_ptr.* = key;
    }
    errdefer if (!result.found_existing) {
        self.allocator.free(result.key_ptr.*);
    };
    const command_lines_duped = try self.allocator.alloc([]const u8, command_lines.len);
    errdefer self.allocator.free(command_lines_duped);
    var i: usize = 0;
    errdefer for (0..i) |j| {
        self.allocator.free(command_lines[j]);
    };
    while (i < command_lines_duped.len) : (i += 1) {
        command_lines_duped[i] = try self.allocator.dupe(u8, command_lines[i]);
    }
    result.value_ptr.* = command_lines_duped;
}

pub fn removeKeyMap(self: *@This(), key_name: []const u8) void {
    if (self.key_map.fetchRemove(key_name)) |removed| {
        self.allocator.free(removed.key);
        for (0..removed.value.len) |i| {
            self.allocator.free(removed.value[i]);
        }
        self.allocator.free(removed.value);
    }
}
