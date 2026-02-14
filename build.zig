const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const coordinate_systems = b.addModule("coordinate_systems", .{
        .root_source_file = b.path("src/coordinate_systems/mod.zig"),
        .target = target,
        .optimize = optimize,
    });

    const utils = b.addModule("utils", .{
        .root_source_file = b.path("src/utils/mod.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "coordinate_systems", .module = coordinate_systems },
        },
    });

    const geometry = b.addModule("geometry", .{
        .root_source_file = b.path("src/geometry/mod.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "coordinate_systems", .module = coordinate_systems },
            .{ .name = "utils", .module = utils },
        },
    });

    const core = b.addModule("core", .{
        .root_source_file = b.path("src/core/mod.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "coordinate_systems", .module = coordinate_systems },
            .{ .name = "geometry", .module = geometry },
            .{ .name = "utils", .module = utils },
        },
    });

    const projections = b.addModule("projections", .{
        .root_source_file = b.path("src/projections/mod.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "coordinate_systems", .module = coordinate_systems },
            .{ .name = "core", .module = core },
            .{ .name = "geometry", .module = geometry },
            .{ .name = "utils", .module = utils },
        },
    });

    const a5_module = b.addModule("a5", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "coordinate_systems", .module = coordinate_systems },
            .{ .name = "core", .module = core },
            .{ .name = "geometry", .module = geometry },
            .{ .name = "projections", .module = projections },
            .{ .name = "utils", .module = utils },
        },
    });

    const exe = b.addExecutable(.{
        .name = "a5-zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "a5", .module = a5_module },
            },
        }),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    run_step.dependOn(&run_cmd.step);

    const test_support = b.addModule("a5_test_support", .{
        .root_source_file = b.path("tests/test_support.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run shared infra tests");
    const qa_step = b.step("qa", "Run Track 7 differential checks and guardrails");
    qa_step.dependOn(test_step);
    const release_gates_step = b.step("release-gates", "Run release gates for completed migration tracks");
    release_gates_step.dependOn(qa_step);
    addTrackTest(
        b,
        target,
        optimize,
        "src/root.zig",
        &[_]std.Build.Module.Import{
            .{ .name = "coordinate_systems", .module = coordinate_systems },
            .{ .name = "core", .module = core },
            .{ .name = "geometry", .module = geometry },
            .{ .name = "projections", .module = projections },
            .{ .name = "utils", .module = utils },
        },
        test_step,
    );
    addTrackTest(
        b,
        target,
        optimize,
        "src/main.zig",
        &[_]std.Build.Module.Import{
            .{ .name = "a5", .module = a5_module },
        },
        test_step,
    );
    addTrackTest(
        b,
        target,
        optimize,
        "tests/shared/track0_infra_test.zig",
        &[_]std.Build.Module.Import{
            .{ .name = "a5", .module = a5_module },
            .{ .name = "a5_test_support", .module = test_support },
        },
        test_step,
    );
    addTrackTest(
        b,
        target,
        optimize,
        "tests/hex.zig",
        &[_]std.Build.Module.Import{
            .{ .name = "a5", .module = a5_module },
        },
        test_step,
    );
    addTrackTest(
        b,
        target,
        optimize,
        "tests/vector.zig",
        &[_]std.Build.Module.Import{
            .{ .name = "a5", .module = a5_module },
        },
        test_step,
    );
    addTrackTest(
        b,
        target,
        optimize,
        "tests/pentagon.zig",
        &[_]std.Build.Module.Import{
            .{ .name = "a5", .module = a5_module },
            .{ .name = "a5_test_support", .module = test_support },
        },
        test_step,
    );
    addTrackTest(
        b,
        target,
        optimize,
        "tests/core_pentagon.zig",
        &[_]std.Build.Module.Import{
            .{ .name = "a5", .module = a5_module },
            .{ .name = "a5_test_support", .module = test_support },
        },
        test_step,
    );
    addTrackTest(
        b,
        target,
        optimize,
        "tests/spherical_polygon.zig",
        &[_]std.Build.Module.Import{
            .{ .name = "a5", .module = a5_module },
            .{ .name = "a5_test_support", .module = test_support },
        },
        test_step,
    );
    addTrackTest(
        b,
        target,
        optimize,
        "tests/spherical_triangle.zig",
        &[_]std.Build.Module.Import{
            .{ .name = "a5", .module = a5_module },
            .{ .name = "a5_test_support", .module = test_support },
        },
        test_step,
    );
    addTrackTest(
        b,
        target,
        optimize,
        "tests/tiling.zig",
        &[_]std.Build.Module.Import{
            .{ .name = "a5", .module = a5_module },
            .{ .name = "a5_test_support", .module = test_support },
        },
        test_step,
    );
    addTrackTest(
        b,
        target,
        optimize,
        "tests/coordinate_transforms.zig",
        &[_]std.Build.Module.Import{
            .{ .name = "a5", .module = a5_module },
        },
        test_step,
    );
    addTrackTest(
        b,
        target,
        optimize,
        "tests/gnomonic.zig",
        &[_]std.Build.Module.Import{
            .{ .name = "a5", .module = a5_module },
            .{ .name = "a5_test_support", .module = test_support },
        },
        test_step,
    );
    addTrackTest(
        b,
        target,
        optimize,
        "tests/authalic.zig",
        &[_]std.Build.Module.Import{
            .{ .name = "a5", .module = a5_module },
            .{ .name = "a5_test_support", .module = test_support },
        },
        test_step,
    );
    addTrackTest(
        b,
        target,
        optimize,
        "tests/polyhedral.zig",
        &[_]std.Build.Module.Import{
            .{ .name = "a5", .module = a5_module },
            .{ .name = "a5_test_support", .module = test_support },
        },
        test_step,
    );
    addTrackTest(
        b,
        target,
        optimize,
        "tests/dodecahedron.zig",
        &[_]std.Build.Module.Import{
            .{ .name = "a5", .module = a5_module },
            .{ .name = "a5_test_support", .module = test_support },
        },
        test_step,
    );
    addTrackTest(
        b,
        target,
        optimize,
        "tests/cell.zig",
        &[_]std.Build.Module.Import{
            .{ .name = "a5", .module = a5_module },
            .{ .name = "a5_test_support", .module = test_support },
        },
        test_step,
    );
    addTrackTest(
        b,
        target,
        optimize,
        "tests/compact.zig",
        &[_]std.Build.Module.Import{
            .{ .name = "a5", .module = a5_module },
            .{ .name = "a5_test_support", .module = test_support },
        },
        test_step,
    );
    addTrackTest(
        b,
        target,
        optimize,
        "tests/api_smoke.zig",
        &[_]std.Build.Module.Import{
            .{ .name = "a5", .module = a5_module },
        },
        test_step,
    );
    addTrackTest(
        b,
        target,
        optimize,
        "tests/hilbert.zig",
        &[_]std.Build.Module.Import{
            .{ .name = "a5", .module = a5_module },
        },
        test_step,
    );
    addTrackTest(
        b,
        target,
        optimize,
        "tests/serialization.zig",
        &[_]std.Build.Module.Import{
            .{ .name = "a5", .module = a5_module },
            .{ .name = "a5_test_support", .module = test_support },
        },
        test_step,
    );
    addTrackTest(
        b,
        target,
        optimize,
        "tests/cell_info.zig",
        &[_]std.Build.Module.Import{
            .{ .name = "a5", .module = a5_module },
            .{ .name = "a5_test_support", .module = test_support },
        },
        test_step,
    );
    addTrackTest(
        b,
        target,
        optimize,
        "tests/dodecahedron_quaternions.zig",
        &[_]std.Build.Module.Import{
            .{ .name = "a5", .module = a5_module },
            .{ .name = "a5_test_support", .module = test_support },
        },
        test_step,
    );
    addTrackTest(
        b,
        target,
        optimize,
        "tests/origin.zig",
        &[_]std.Build.Module.Import{
            .{ .name = "a5", .module = a5_module },
            .{ .name = "a5_test_support", .module = test_support },
        },
        test_step,
    );
    addTrackTest(
        b,
        target,
        optimize,
        "tests/crs.zig",
        &[_]std.Build.Module.Import{
            .{ .name = "a5", .module = a5_module },
            .{ .name = "a5_test_support", .module = test_support },
        },
        test_step,
    );
    addTrackTest(
        b,
        target,
        optimize,
        "tests/qa_differential_guardrails.zig",
        &[_]std.Build.Module.Import{
            .{ .name = "a5", .module = a5_module },
            .{ .name = "a5_test_support", .module = test_support },
        },
        qa_step,
    );
    addTrackTest(
        b,
        target,
        optimize,
        "tests/qa_perf_memory_smoke.zig",
        &[_]std.Build.Module.Import{
            .{ .name = "a5", .module = a5_module },
            .{ .name = "a5_test_support", .module = test_support },
        },
        qa_step,
    );
}

fn addTrackTest(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    source_file: []const u8,
    imports: []const std.Build.Module.Import,
    test_step: *std.Build.Step,
) void {
    const test_module = b.createModule(.{
        .root_source_file = b.path(source_file),
        .target = target,
        .optimize = optimize,
        .imports = imports,
    });
    const test_bin = b.addTest(.{ .root_module = test_module });
    const run_test = b.addRunArtifact(test_bin);
    test_step.dependOn(&run_test.step);
}
