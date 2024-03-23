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
    const test_e2e_step = addTest(b, "e2e", options);
    const test_module_definition_step = addTest(b, "ModuleDefinition", options);

    b.getInstallStep().dependOn(test_unit_step);
    b.getInstallStep().dependOn(test_module_definition_step);

    if (std.fs.cwd().access("src/tmp.zig", .{})) |_| {
        addRun(b, "tmp", options);
        const test_tmp_step = addTest(b, "tmp", options);
        b.getInstallStep().dependOn(test_tmp_step);
    } else |_| {}

    const test_all_step = b.step("test-all", "");
    test_all_step.dependOn(test_unit_step);
    test_all_step.dependOn(test_e2e_step);
}

fn addMain(b: *std.Build, options: Options) void {
    const exe = b.addExecutable(.{
        .name = "dew",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = options.target,
        .optimize = options.optimize,
    });
    linkLibraries(b, exe);
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
    linkLibraries(b, exe);
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
    linkLibraries(b, tests);
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test-" ++ name, "");
    test_step.dependOn(&run_tests.step);
    return test_step;
}

fn linkLibraries(b: *std.Build, exe: *std.Build.Step.Compile) void {
    exe.root_module.addImport("yaml", b.addModule("yaml", .{
        .root_source_file = .{
            .path = "lib/zig-yaml/src/yaml.zig",
        },
    }));
    exe.root_module.addImport("ziglyph", b.addModule("ziglyph", .{
        .root_source_file = .{
            .path = "lib/ziglyph/src/ziglyph.zig",
        },
    }));
    exe.root_module.addImport("clap", b.addModule("clap", .{
        .root_source_file = .{
            .path = "lib/zig-clap/clap.zig",
        },
    }));

    const libyaml_root: []const u8 = std.os.getenv("LIBYAML_ROOT").?;
    exe.addIncludePath(.{
        .path = std.fmt.allocPrint(b.allocator, "{s}/include", .{libyaml_root}) catch unreachable,
    });
    exe.addLibraryPath(.{
        .path = std.fmt.allocPrint(b.allocator, "{s}/lib", .{libyaml_root}) catch unreachable,
    });
    exe.linkSystemLibrary("yaml-0.2");
}
