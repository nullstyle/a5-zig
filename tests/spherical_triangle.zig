const std = @import("std");
const a5 = @import("a5");
const support = @import("a5_test_support");

const assertions = support.assertions;
const geometry = a5.geometry;
const Cartesian = a5.coordinate_systems.Cartesian;
const TOLERANCE: f64 = 1e-6;

const SlerpTest = struct {
    t: f64,
    result: [3]f64,
};

const ContainsPointTest = struct {
    point: [3]f64,
    result: f64,
};

const Fixture = struct {
    vertices: []const [3]f64,
    boundary1: []const [3]f64,
    boundary2: []const [3]f64,
    boundary3: []const [3]f64,
    slerpTests: []const SlerpTest,
    containsPointTests: []const ContainsPointTest,
    area: f64,
};

fn cartesianFrom(f: [3]f64) Cartesian {
    return Cartesian.new(f[0], f[1], f[2]);
}

fn closeArray(actual: [3]f64, expected: [3]f64) !void {
    try assertions.expectApproxEqFloat(actual[0], expected[0], TOLERANCE);
    try assertions.expectApproxEqFloat(actual[1], expected[1], TOLERANCE);
    try assertions.expectApproxEqFloat(actual[2], expected[2], TOLERANCE);
}

fn verticesFromFixture(allocator: std.mem.Allocator, values: []const [3]f64) ![]Cartesian {
    var vertices = try allocator.alloc(Cartesian, values.len);
    for (values, 0..) |value, i| {
        vertices[i] = cartesianFrom(value);
    }
    return vertices;
}

test "geometry.spherical_triangle.constructor" {
    try std.testing.expectError(
        geometry.SphericalTriangleShape.Error.InvalidVertexCount,
        geometry.SphericalTriangleShape.new(&[_]Cartesian{}),
    );
    try std.testing.expectError(
        geometry.SphericalTriangleShape.Error.InvalidVertexCount,
        geometry.SphericalTriangleShape.new(&[_]Cartesian{
            Cartesian.new(1.0, 0.0, 0.0),
            Cartesian.new(0.0, 1.0, 0.0),
        }),
    );
    try std.testing.expectError(
        geometry.SphericalTriangleShape.Error.InvalidVertexCount,
        geometry.SphericalTriangleShape.new(&[_]Cartesian{
            Cartesian.new(1.0, 0.0, 0.0),
            Cartesian.new(0.0, 1.0, 0.0),
            Cartesian.new(0.0, 0.0, 1.0),
            Cartesian.new(1.0, 1.0, 1.0),
        }),
    );

    const valid = try geometry.SphericalTriangleShape.new(&[_]Cartesian{
        Cartesian.new(1.0, 0.0, 0.0),
        Cartesian.new(0.0, 1.0, 0.0),
        Cartesian.new(0.0, 0.0, 1.0),
    });
    _ = valid;
}

test "geometry.spherical_triangle.boundary" {
    var parsed = try support.fixtures.parseFixture([]const Fixture, "spherical-triangle.json", std.testing.allocator);
    defer parsed.deinit();
    const fixtures = parsed.value;

    for (fixtures) |fixture| {
        const vertices = try verticesFromFixture(std.testing.allocator, fixture.vertices);
        defer std.testing.allocator.free(vertices);

        const triangle = try geometry.SphericalTriangleShape.new(vertices);

        for (1..4) |n_segments| {
            const expected = switch (n_segments) {
                1 => fixture.boundary1,
                2 => fixture.boundary2,
                3 => fixture.boundary3,
                else => unreachable,
            };
            const boundary = try triangle.get_boundary(std.testing.allocator, n_segments, true);
            defer std.testing.allocator.free(boundary);

            try std.testing.expectEqual(expected.len, boundary.len);
            for (boundary, 0..) |actual, i| {
                const coords = actual.toArray();
                try closeArray(coords, expected[i]);
            }
        }
    }
}

test "geometry.spherical_triangle.slerp" {
    var parsed = try support.fixtures.parseFixture([]const Fixture, "spherical-triangle.json", std.testing.allocator);
    defer parsed.deinit();
    const fixtures = parsed.value;

    for (fixtures) |fixture| {
        const vertices = try verticesFromFixture(std.testing.allocator, fixture.vertices);
        defer std.testing.allocator.free(vertices);
        const triangle = try geometry.SphericalTriangleShape.new(vertices);

        for (fixture.slerpTests) |case| {
            const actual = triangle.slerp(case.t);
            const actual_arr = actual.toArray();
            try closeArray(actual_arr, case.result);

            const length = std.math.sqrt(
                actual.x() * actual.x() + actual.y() * actual.y() + actual.z() * actual.z(),
            );
            try assertions.expectApproxEqFloat(length, 1.0, 1e-10);
        }
    }
}

test "geometry.spherical_triangle.contains_point" {
    var parsed = try support.fixtures.parseFixture([]const Fixture, "spherical-triangle.json", std.testing.allocator);
    defer parsed.deinit();
    const fixtures = parsed.value;

    for (fixtures) |fixture| {
        const vertices = try verticesFromFixture(std.testing.allocator, fixture.vertices);
        defer std.testing.allocator.free(vertices);
        const triangle = try geometry.SphericalTriangleShape.new(vertices);

        for (fixture.containsPointTests) |case| {
            const point = cartesianFrom(case.point);
            const actual = triangle.contains_point(point);
            try assertions.expectApproxEqFloat(actual, case.result, TOLERANCE);
        }
    }
}

test "geometry.spherical_triangle.get_area" {
    var parsed = try support.fixtures.parseFixture([]const Fixture, "spherical-triangle.json", std.testing.allocator);
    defer parsed.deinit();
    const fixtures = parsed.value;

    for (fixtures) |fixture| {
        const vertices = try verticesFromFixture(std.testing.allocator, fixture.vertices);
        defer std.testing.allocator.free(vertices);
        var triangle = try geometry.SphericalTriangleShape.new(vertices);

        const area = triangle.get_area().get();
        try assertions.expectApproxEqFloat(area, fixture.area, TOLERANCE);
        try std.testing.expect(area != 0.0);
        try std.testing.expect(@abs(area) <= 2.0 * std.math.pi);
    }
}
