const ModuleRegistry = @This();
const std = @import("std");
const Module = @import("Module.zig");
const Editor = @import("Editor.zig");
const builtin_modules = @import("builtin_modules.zig");

editor: *Editor,
modules: std.StringHashMap(Module),

pub fn init(editor: *Editor) ModuleRegistry {
    return .{
        .editor = editor,
        .modules = std.StringHashMap(Module).init(editor.allocator),
    };
}

pub fn deinit(self: *ModuleRegistry) void {
    var module_it = self.modules.iterator();
    while (module_it.next()) |module| {
        self.editor.allocator.free(module.key_ptr.*);
        module.value_ptr.deinit();
    }
    self.modules.deinit();
}

pub fn append(self: *ModuleRegistry, module: Module) !void {
    const key = try self.editor.allocator.dupe(u8, module.definition.name);
    errdefer self.editor.allocator.free(key);
    try self.modules.putNoClobber(key, module);
}

pub fn get(self: *const ModuleRegistry, name: []const u8) ?Module {
    return self.modules.get(name);
}

pub fn appendBuiltinModules(self: *ModuleRegistry) !void {
    var selections = try builtin_modules.Selections.init(self.editor);
    errdefer selections.module().deinit();
    try self.append(selections.module());
}

pub fn iterator(self: *ModuleRegistry) std.StringHashMap(Module).ValueIterator {
    return self.modules.valueIterator();
}
