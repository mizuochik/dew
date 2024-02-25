const std = @import("std");

const Options = struct {
    name: []const u8 = "",
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const options = .{
        .target = target,
        .optimize = optimize,
    };

    const ziglyph = b.addStaticLibrary(.{
        .name = "ziglyph",
        .root_source_file = .{ .path = "lib/ziglyph/src/ziglyph.zig" },
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "dew",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("ziglyph", &ziglyph.root_module);
    exe.root_module.addImport("clap", b.dependency("clap", .{
        .target = target,
        .optimize = optimize,
    }).module("clap"));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const tests = b.addTest(.{
        .root_source_file = .{ .path = "src/tests.zig" },
        .target = target,
        .optimize = optimize,
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_tests.step);

    addTest(b, "parser", options);
    if (std.fs.cwd().access("src/tmp.zig", .{})) |_|
        addTest(b, "tmp", options)
    else |_| {}
}

fn addTest(b: *std.Build, comptime name: []const u8, options: Options) void {
    const clap = b.dependency("clap", .{
        .target = options.target,
        .optimize = options.optimize,
    });
    const tests = b.addTest(.{
        .root_source_file = .{ .path = "src/" ++ name ++ ".zig" },
        .target = options.target,
        .optimize = options.optimize,
    });
    tests.root_module.addImport("clap", clap.module("clap"));
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test-" ++ name, "");
    test_step.dependOn(&run_tests.step);
}
