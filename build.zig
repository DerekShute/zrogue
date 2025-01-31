const std = @import("std");

//
// Build directives
//

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zrogue",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.linkLibC();
    exe.linkSystemLibrary("ncursesw");
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    //
    // Unit Tests
    //

    const unit_tests = b.addTest(.{
        .root_source_file = b.path("unit_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    unit_tests.linkLibC();
    unit_tests.linkSystemLibrary("ncursesw");

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}

// EOF
