const std = @import("std");
const Module = @import("Module.zig");
const Editor = @import("Editor.zig");
const builtin_modules = @import("builtin_modules.zig");

editor: *Editor,
modules: std.StringHashMap(Module),

pub fn init(editor: *Editor) @This() {
    return .{
        .editor = editor,
        .modules = std.StringHashMap(Module).init(editor.allocator),
    };
}

pub fn deinit(self: *@This()) void {
    var module_it = self.modules.iterator();
    while (module_it.next()) |module| {
        self.editor.allocator.free(module.key_ptr.*);
        module.value_ptr.deinit();
    }
    self.modules.deinit();
}

pub fn append(self: *@This(), module: Module) !void {
    const key = try self.editor.allocator.dupe(u8, module.definition.name);
    errdefer self.editor.allocator.free(key);
    try self.modules.putNoClobber(key, module);
}

pub fn get(self: *const @This(), name: []const u8) ?Module {
    return self.modules.get(name);
}

pub fn appendBuiltinModules(self: *@This()) !void {
    var cursors = try builtin_modules.Cursors.init(self.editor);
    errdefer cursors.module().deinit();
    try self.append(cursors.module());
}
