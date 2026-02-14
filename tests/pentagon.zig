const std = @import("std");
const support = @import("a5_test_support");
const a5 = @import("a5");

const Face = a5.coordinate_systems.Face;
const geometry = a5.geometry;
const assertions = support.assertions;
const fixtures = support.fixtures;

const TOLERANCE: f64 = 1e-6;

const ContainsPointTest = struct {
    point: [2]f64,
    result: f64,
};

const TransformTests = struct {
    scale: []const [2]f64,
    rotate180: []const [2]f64,
    reflectY: []const [2]f64,
    translate: []const [2]f64,
};

const SplitEdgesTests = struct {
    segments2: []const [2]f64,
    segments3: []const [2]f64,
};

const Fixture = struct {
    vertices: []const [2]f64,
    area: f64,
    center: [2]f64,
    containsPointTests: []const ContainsPointTest,
    transformTests: TransformTests,
    splitEdgesTests: SplitEdgesTests,
};

fn expectFaceArrayClose(actual: []const Face, expected: []const [2]f64) !void {
    try std.testing.expectEqual(actual.len, expected.len);
    for (actual, 0..) |point, i| {
        try assertions.expectApproxEqFloat(point.x(), expected[i][0], TOLERANCE);
        try assertions.expectApproxEqFloat(point.y(), expected[i][1], TOLERANCE);
    }
}

test "geometry.pentagon.contains_point" {
    var parsed = try fixtures.parseFixture([]const Fixture, "geometry/pentagon.json", std.testing.allocator);
    defer parsed.deinit();
    const tests = parsed.value;

    for (tests) |fixture| {
        var verts = [_]Face{
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
        };

        for (fixture.vertices, 0..) |vertex, i| {
            verts[i] = Face.new(vertex[0], vertex[1]);
        }

        const shape = geometry.PentagonShape.new(verts);
        for (fixture.containsPointTests) |test_case| {
            const point = Face.new(test_case.point[0], test_case.point[1]);
            const actual = shape.contains_point(point);
            try assertions.expectApproxEqFloat(actual, test_case.result, TOLERANCE);
        }
    }
}

test "geometry.pentagon.get_area" {
    var parsed = try fixtures.parseFixture([]const Fixture, "geometry/pentagon.json", std.testing.allocator);
    defer parsed.deinit();
    const tests = parsed.value;

    for (tests) |fixture| {
        var verts = [_]Face{
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
        };

        for (fixture.vertices, 0..) |vertex, i| {
            verts[i] = Face.new(vertex[0], vertex[1]);
        }

        const shape = geometry.PentagonShape.new(verts);
        try assertions.expectApproxEqFloat(shape.get_area(), fixture.area, TOLERANCE);
    }
}

test "geometry.pentagon.get_center" {
    var parsed = try fixtures.parseFixture([]const Fixture, "geometry/pentagon.json", std.testing.allocator);
    defer parsed.deinit();
    const tests = parsed.value;

    for (tests) |fixture| {
        var verts = [_]Face{
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
        };
        for (fixture.vertices, 0..) |vertex, i| {
            verts[i] = Face.new(vertex[0], vertex[1]);
        }

        const shape = geometry.PentagonShape.new(verts);
        const center = shape.get_center();
        try assertions.expectApproxEqFloat(center.x(), fixture.center[0], TOLERANCE);
        try assertions.expectApproxEqFloat(center.y(), fixture.center[1], TOLERANCE);
    }
}

test "geometry.pentagon.scale_transformation" {
    var parsed = try fixtures.parseFixture([]const Fixture, "geometry/pentagon.json", std.testing.allocator);
    defer parsed.deinit();
    const tests = parsed.value;

    for (tests) |fixture| {
        var verts = [_]Face{
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
        };
        for (fixture.vertices, 0..) |vertex, i| {
            verts[i] = Face.new(vertex[0], vertex[1]);
        }

        var pentagon = geometry.PentagonShape.new(verts);
        _ = pentagon.scale(2.0);
        const actual = pentagon.get_vertices_vec();
        try expectFaceArrayClose(actual, fixture.transformTests.scale);
    }
}

test "geometry.pentagon.rotate180_transformation" {
    var parsed = try fixtures.parseFixture([]const Fixture, "geometry/pentagon.json", std.testing.allocator);
    defer parsed.deinit();
    const tests = parsed.value;

    for (tests) |fixture| {
        var verts = [_]Face{
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
        };
        for (fixture.vertices, 0..) |vertex, i| {
            verts[i] = Face.new(vertex[0], vertex[1]);
        }

        var pentagon = geometry.PentagonShape.new(verts);
        _ = pentagon.rotate180();
        const actual = pentagon.get_vertices_vec();
        try expectFaceArrayClose(actual, fixture.transformTests.rotate180);
    }
}

test "geometry.pentagon.reflect_y_transformation" {
    var parsed = try fixtures.parseFixture([]const Fixture, "geometry/pentagon.json", std.testing.allocator);
    defer parsed.deinit();
    const tests = parsed.value;

    for (tests) |fixture| {
        var verts = [_]Face{
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
        };
        for (fixture.vertices, 0..) |vertex, i| {
            verts[i] = Face.new(vertex[0], vertex[1]);
        }

        var pentagon = geometry.PentagonShape.new(verts);
        _ = pentagon.reflect_y();
        const actual = pentagon.get_vertices_vec();
        try expectFaceArrayClose(actual, fixture.transformTests.reflectY);
    }
}

test "geometry.pentagon.translate_transformation" {
    var parsed = try fixtures.parseFixture([]const Fixture, "geometry/pentagon.json", std.testing.allocator);
    defer parsed.deinit();
    const tests = parsed.value;

    for (tests) |fixture| {
        var verts = [_]Face{
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
        };
        for (fixture.vertices, 0..) |vertex, i| {
            verts[i] = Face.new(vertex[0], vertex[1]);
        }

        var pentagon = geometry.PentagonShape.new(verts);
        _ = pentagon.translate(Face.new(1.0, 1.0));
        const actual = pentagon.get_vertices_vec();
        try expectFaceArrayClose(actual, fixture.transformTests.translate);
    }
}

test "geometry.pentagon.split_edges_segments2" {
    var parsed = try fixtures.parseFixture([]const Fixture, "geometry/pentagon.json", std.testing.allocator);
    defer parsed.deinit();
    const tests = parsed.value;

    for (tests) |fixture| {
        var verts = [_]Face{
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
        };
        for (fixture.vertices, 0..) |vertex, i| {
            verts[i] = Face.new(vertex[0], vertex[1]);
        }

        const split = geometry.PentagonShape.new(verts).split_edges(2);
        const points = split.get_vertices_vec();
        try expectFaceArrayClose(points, fixture.splitEdgesTests.segments2);
    }
}

test "geometry.pentagon.split_edges_segments3" {
    var parsed = try fixtures.parseFixture([]const Fixture, "geometry/pentagon.json", std.testing.allocator);
    defer parsed.deinit();
    const tests = parsed.value;

    for (tests) |fixture| {
        var verts = [_]Face{
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
            Face.new(0.0, 0.0),
        };
        for (fixture.vertices, 0..) |vertex, i| {
            verts[i] = Face.new(vertex[0], vertex[1]);
        }

        const split = geometry.PentagonShape.new(verts).split_edges(3);
        const points = split.get_vertices_vec();
        try expectFaceArrayClose(points, fixture.splitEdgesTests.segments3);
    }
}
