const std = @import("std");
const a5 = @import("a5");
const support = @import("a5_test_support");

const assertions = support.assertions;
const core = a5.core;
const geometry = a5.geometry;
const Face = a5.coordinate_systems.Face;
const IJ = a5.coordinate_systems.IJ;
const Radians = a5.coordinate_systems.Radians;
const Polar = a5.coordinate_systems.Polar;
const constants = core.constants;

const TOLERANCE = 1e-15;

const AnchorData = struct {
    offset: [2]f64,
    flips: [2]i8,
    k: u8,
};

const PentagonInput = struct {
    resolution: i32,
    quintant: usize,
    anchor: AnchorData,
};

const GeometryOutput = struct {
    vertices: []const [2]f64,
    area: f64,
    center: [2]f64,
};

const PentagonCase = struct {
    input: PentagonInput,
    output: GeometryOutput,
};

const QuintantInput = struct {
    quintant: usize,
};

const QuintantCase = struct {
    input: QuintantInput,
    output: GeometryOutput,
};

const FaceOutput = struct {
    vertices: []const [2]f64,
    area: f64,
    center: [2]f64,
};

const PolarInput = struct {
    polar: [2]f64,
};

const PolarOutput = struct {
    quintant: usize,
};

const QuintantPolarCase = struct {
    input: PolarInput,
    output: PolarOutput,
};

const Fixtures = struct {
    @"getPentagonVertices": []const PentagonCase,
    @"getQuintantVertices": []const QuintantCase,
    @"getFaceVertices": FaceOutput,
    @"getQuintantPolar": []const QuintantPolarCase,
};

fn expectFaceSlice(actual: []const Face, expected: []const [2]f64) !void {
    try std.testing.expectEqual(expected.len, actual.len);
    for (actual, 0..) |point, i| {
        try assertions.expectApproxEqFloat(point.x(), expected[i][0], TOLERANCE);
        try assertions.expectApproxEqFloat(point.y(), expected[i][1], TOLERANCE);
    }
}

fn closeTo(actual: f64, expected: f64) !void {
    try assertions.expectApproxEqFloat(actual, expected, TOLERANCE);
}

test "core.tiling.get_pentagon_vertices" {
    var parsed = try support.fixtures.parseFixture(Fixtures, "tiling.json", std.testing.allocator);
    defer parsed.deinit();
    const fixtures = parsed.value;

    for (fixtures.getPentagonVertices) |test_case| {
        const offset = IJ.new(test_case.input.anchor.offset[0], test_case.input.anchor.offset[1]);
        const anchor = struct {
            k: u8,
            offset: IJ,
            flips: [2]i8,
        }{
            .k = test_case.input.anchor.k,
            .offset = offset,
            .flips = test_case.input.anchor.flips,
        };

        const shape = core.tiling.get_pentagon_vertices(
            test_case.input.resolution,
            test_case.input.quintant,
            anchor,
        );
        const vertices = shape.get_vertices_vec();
        const area = shape.get_area();

        try expectFaceSlice(vertices, test_case.output.vertices);
        try closeTo(area, test_case.output.area);

        const center = shape.get_center();
        try assertions.expectApproxEqFloat(center.x(), test_case.output.center[0], TOLERANCE);
        try assertions.expectApproxEqFloat(center.y(), test_case.output.center[1], TOLERANCE);
    }
}

test "core.tiling.get_quintant_vertices" {
    var parsed = try support.fixtures.parseFixture(Fixtures, "tiling.json", std.testing.allocator);
    defer parsed.deinit();
    const fixtures = parsed.value;

    for (fixtures.getQuintantVertices) |test_case| {
        const shape = core.tiling.get_quintant_vertices(test_case.input.quintant);
        const vertices = shape.get_vertices_vec();
        const area = shape.get_area();

        try expectFaceSlice(vertices, test_case.output.vertices);
        try closeTo(area, test_case.output.area);

        const center = shape.get_center();
        try assertions.expectApproxEqFloat(center.x(), test_case.output.center[0], TOLERANCE);
        try assertions.expectApproxEqFloat(center.y(), test_case.output.center[1], TOLERANCE);
    }
}

test "core.tiling.get_face_vertices" {
    var parsed = try support.fixtures.parseFixture(Fixtures, "tiling.json", std.testing.allocator);
    defer parsed.deinit();
    const fixture = parsed.value.getFaceVertices;

    const shape = core.tiling.get_face_vertices();
    const vertices = shape.get_vertices_vec();
    const area = shape.get_area();

    try expectFaceSlice(vertices, fixture.vertices);
    try closeTo(area, fixture.area);

    const center = shape.get_center();
    try assertions.expectApproxEqFloat(center.x(), fixture.center[0], TOLERANCE);
    try assertions.expectApproxEqFloat(center.y(), fixture.center[1], TOLERANCE);
}

test "core.tiling.get_quintant_polar" {
    var parsed = try support.fixtures.parseFixture(Fixtures, "tiling.json", std.testing.allocator);
    defer parsed.deinit();
    const fixtures = parsed.value;

    for (fixtures.getQuintantPolar) |case| {
        const polar = Polar.new(case.input.polar[0], Radians.new_unchecked(case.input.polar[1]));
        const result = core.tiling.get_quintant_polar(polar);
        try std.testing.expectEqual(case.output.quintant, result);
    }
}
