const std = @import("std");

const Options = struct {
    name: []const u8 = "",
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
};

pub fn build(b: *std.Build) void {
    const options = .{
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    };

    addMain(b, options);

    const test_unit_step = addTest(b, "unit", options);
    _ = addTest(b, "parser", options);
    _ = addTest(b, "e2e", options);

    b.getInstallStep().dependOn(test_unit_step);

    if (std.fs.cwd().access("src/tmp.zig", .{})) |_| {
        addRun(b, "tmp", options);
        const test_tmp_step = addTest(b, "tmp", options);
        b.getInstallStep().dependOn(test_tmp_step);
    } else |_| {}
}

fn addMain(b: *std.Build, options: Options) void {
    const exe = b.addExecutable(.{
        .name = "dew",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = options.target,
        .optimize = options.optimize,
    });
    addImports(b, &exe.root_module);
    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

fn addRun(b: *std.Build, comptime name: []const u8, options: Options) void {
    const exe = b.addExecutable(.{
        .name = name,
        .root_source_file = .{ .path = "src/" ++ name ++ ".zig" },
        .target = options.target,
        .optimize = options.optimize,
    });
    addImports(b, &exe.root_module);
    const run = b.addRunArtifact(exe);
    const run_step = b.step("run-" ++ name, "");
    run_step.dependOn(&run.step);
}

fn addTest(b: *std.Build, comptime name: []const u8, options: Options) *std.Build.Step {
    const tests = b.addTest(.{
        .root_source_file = .{ .path = "src/" ++ name ++ ".zig" },
        .target = options.target,
        .optimize = options.optimize,
    });
    addImports(b, &tests.root_module);
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test-" ++ name, "");
    test_step.dependOn(&run_tests.step);
    return test_step;
}

fn addImports(b: *std.Build, module: *std.Build.Module) void {
    module.addImport("yaml", b.addModule("yaml", .{
        .root_source_file = .{
            .path = "lib/zig-yaml/src/yaml.zig",
        },
    }));
    module.addImport("ziglyph", b.addModule("ziglyph", .{
        .root_source_file = .{
            .path = "lib/ziglyph/src/ziglyph.zig",
        },
    }));
    module.addImport("clap", b.dependency("clap", .{}).module("clap"));
}
