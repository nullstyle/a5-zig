const std = @import("std");
const a5 = @import("a5");
const support = @import("a5_test_support");
const support_fixtures = support.fixtures;

const CRS = a5.projections.CRS;
const coordinate_systems = a5.coordinate_systems;

const TOLERANCE = 1e-10;

const Fixture = []const [3]f64;

fn loadExpectedVertices() !std.json.Parsed(Fixture) {
    return support_fixtures.parseFixture(Fixture, "crs-vertices.json", std.testing.allocator);
}

test "crs should contain exactly 62 vertices" {
    var parsed = try loadExpectedVertices();
    defer parsed.deinit();
    const expected = parsed.value;

    const crs = try CRS.new();
    try std.testing.expectEqual(@as(usize, 62), crs.len);
    try std.testing.expectEqual(expected.len, crs.len);
}

test "crs should find north pole vertex" {
    var crs = try CRS.new();
    const north_pole = coordinate_systems.Cartesian.new(0.0, 0.0, 1.0);
    _ = try crs.get_vertex(north_pole);
}

test "crs should match expected fixture vertices" {
    var parsed = try loadExpectedVertices();
    defer parsed.deinit();
    const expected = parsed.value;

    var crs = try CRS.new();
    for (expected) |expected_vertex| {
        const point = coordinate_systems.Cartesian.new(
            expected_vertex[0],
            expected_vertex[1],
            expected_vertex[2],
        );
        const found = try crs.get_vertex(point);
        try std.testing.expect(std.math.approxEqAbs(f64, found.x(), expected_vertex[0], TOLERANCE));
        try std.testing.expect(std.math.approxEqAbs(f64, found.y(), expected_vertex[1], TOLERANCE));
        try std.testing.expect(std.math.approxEqAbs(f64, found.z(), expected_vertex[2], TOLERANCE));
    }
}

test "crs should fail on non-vertex lookup" {
    var crs = try CRS.new();
    const point = coordinate_systems.Cartesian.new(1.0, 0.0, 0.0);
    try std.testing.expectError(CRS.Error.VertexNotFound, crs.get_vertex(point));
}

test "crs expected vertices are normalized" {
    var parsed = try loadExpectedVertices();
    defer parsed.deinit();

    for (parsed.value) |vertex| {
        const len = std.math.sqrt(
            vertex[0] * vertex[0] + vertex[1] * vertex[1] + vertex[2] * vertex[2],
        );
        try std.testing.expect(std.math.approxEqAbs(f64, len, 1.0, 1e-15));
    }
}

test "crs vertex lookup should be deterministic" {
    var parsed = try loadExpectedVertices();
    defer parsed.deinit();

    const vertex = parsed.value[0];
    var crs = try CRS.new();
    const point = coordinate_systems.Cartesian.new(vertex[0], vertex[1], vertex[2]);
    const first = try crs.get_vertex(point);
    const second = try crs.get_vertex(point);

    try std.testing.expect(std.math.approxEqAbs(f64, first.x(), second.x(), TOLERANCE));
    try std.testing.expect(std.math.approxEqAbs(f64, first.y(), second.y(), TOLERANCE));
    try std.testing.expect(std.math.approxEqAbs(f64, first.z(), second.z(), TOLERANCE));
}
