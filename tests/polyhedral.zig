const std = @import("std");
const a5 = @import("a5");
const support = @import("a5_test_support");
const support_fixtures = support.fixtures;

const coordinate_systems = a5.coordinate_systems;
const polyhedral = a5.projections.polyhedral;
const vector = a5.utils.vector;

const Cartesian = coordinate_systems.Cartesian;
const Face = coordinate_systems.Face;
const FaceTriangle = coordinate_systems.FaceTriangle;
const SphericalTriangle = coordinate_systems.SphericalTriangle;

const ForwardCase = struct {
    input: [3]f64,
    expected: [2]f64,
};

const InverseCase = struct {
    input: [2]f64,
    expected: [3]f64,
};

const StaticData = struct {
    @"TEST_SPHERICAL_TRIANGLE": [3][3]f64,
    @"TEST_FACE_TRIANGLE": [3][2]f64,
};

const Fixture = struct {
    forward: []ForwardCase,
    inverse: []InverseCase,
    @"static": StaticData,
};

const TOLERANCE: f64 = 1e-10;

fn closeTo(a: f64, b: f64, tolerance: f64) bool {
    return @abs(a - b) < tolerance;
}

fn arrayToCartesian(arr: [3]f64) Cartesian {
    return Cartesian.fromArray(arr);
}

fn arrayToFace(arr: [2]f64) Face {
    return Face.fromArray(arr);
}

fn arraysToSphericalTriangle(arrays: [3][3]f64) SphericalTriangle {
    return SphericalTriangle.new(
        arrayToCartesian(arrays[0]),
        arrayToCartesian(arrays[1]),
        arrayToCartesian(arrays[2]),
    );
}

fn arraysToFaceTriangle(arrays: [3][2]f64) FaceTriangle {
    return FaceTriangle.new(
        arrayToFace(arrays[0]),
        arrayToFace(arrays[1]),
        arrayToFace(arrays[2]),
    );
}

fn vec3Angle(a: Cartesian, b: Cartesian) f64 {
    const dot_product = a.x() * b.x() + a.y() * b.y() + a.z() * b.z();
    const len_a = vector.vec3_length(a);
    const len_b = vector.vec3_length(b);
    const cos_angle = std.math.clamp(dot_product / (len_a * len_b), -1.0, 1.0);
    return std.math.acos(cos_angle);
}

test "polyhedral forward projection matches fixture data" {
    var parsed = try support_fixtures.parseFixture(Fixture, "polyhedral.json", std.testing.allocator);
    defer parsed.deinit();
    const fixture = parsed.value;

    const projection = polyhedral.PolyhedralProjection{};
    const spherical_triangle = arraysToSphericalTriangle(fixture.@"static".@"TEST_SPHERICAL_TRIANGLE");
    const face_triangle = arraysToFaceTriangle(fixture.@"static".@"TEST_FACE_TRIANGLE");

    for (fixture.forward) |case| {
        const input = arrayToCartesian(case.input);
        const expected = arrayToFace(case.expected);
        const result = projection.forward(input, spherical_triangle, face_triangle);
        try std.testing.expect(closeTo(result.x(), expected.x(), TOLERANCE));
        try std.testing.expect(closeTo(result.y(), expected.y(), TOLERANCE));
    }
}

test "polyhedral round trip from forward fixtures stays within tolerance" {
    var parsed = try support_fixtures.parseFixture(Fixture, "polyhedral.json", std.testing.allocator);
    defer parsed.deinit();
    const fixture = parsed.value;

    const projection = polyhedral.PolyhedralProjection{};
    const spherical_triangle = arraysToSphericalTriangle(fixture.@"static".@"TEST_SPHERICAL_TRIANGLE");
    const face_triangle = arraysToFaceTriangle(fixture.@"static".@"TEST_FACE_TRIANGLE");

    var largest_error: f64 = 0.0;
    for (fixture.forward) |case| {
        const spherical = arrayToCartesian(case.input);
        const face = projection.forward(spherical, spherical_triangle, face_triangle);
        const result = projection.inverse(face, face_triangle, spherical_triangle);
        const error_value = vector.vec3_distance(result, spherical);
        largest_error = @max(largest_error, error_value);

        try std.testing.expect(closeTo(result.x(), spherical.x(), TOLERANCE));
        try std.testing.expect(closeTo(result.y(), spherical.y(), TOLERANCE));
        try std.testing.expect(closeTo(result.z(), spherical.z(), TOLERANCE));
    }

    const AUTHALIC_RADIUS: f64 = 6371.0072;
    const max_angle = @max(
        vec3Angle(spherical_triangle.a, spherical_triangle.b),
        @max(
            vec3Angle(spherical_triangle.b, spherical_triangle.c),
            vec3Angle(spherical_triangle.c, spherical_triangle.a),
        ),
    );
    const max_arc_length_mm = AUTHALIC_RADIUS * max_angle * 1e9;
    const DESIRED_MM_PRECISION: f64 = 0.01;
    try std.testing.expect(largest_error * max_arc_length_mm < DESIRED_MM_PRECISION);
}

test "polyhedral inverse projection matches fixture data" {
    var parsed = try support_fixtures.parseFixture(Fixture, "polyhedral.json", std.testing.allocator);
    defer parsed.deinit();
    const fixture = parsed.value;

    const projection = polyhedral.PolyhedralProjection{};
    const spherical_triangle = arraysToSphericalTriangle(fixture.@"static".@"TEST_SPHERICAL_TRIANGLE");
    const face_triangle = arraysToFaceTriangle(fixture.@"static".@"TEST_FACE_TRIANGLE");

    for (fixture.inverse) |case| {
        const input = arrayToFace(case.input);
        const expected = arrayToCartesian(case.expected);
        const result = projection.inverse(input, face_triangle, spherical_triangle);
        try std.testing.expect(closeTo(result.x(), expected.x(), TOLERANCE));
        try std.testing.expect(closeTo(result.y(), expected.y(), TOLERANCE));
        try std.testing.expect(closeTo(result.z(), expected.z(), TOLERANCE));
    }
}

test "polyhedral round trip from inverse fixtures stays within tolerance" {
    var parsed = try support_fixtures.parseFixture(Fixture, "polyhedral.json", std.testing.allocator);
    defer parsed.deinit();
    const fixture = parsed.value;

    const projection = polyhedral.PolyhedralProjection{};
    const spherical_triangle = arraysToSphericalTriangle(fixture.@"static".@"TEST_SPHERICAL_TRIANGLE");
    const face_triangle = arraysToFaceTriangle(fixture.@"static".@"TEST_FACE_TRIANGLE");

    for (fixture.inverse) |case| {
        const face_point = arrayToFace(case.input);
        const spherical = projection.inverse(face_point, face_triangle, spherical_triangle);
        const result = projection.forward(spherical, spherical_triangle, face_triangle);
        try std.testing.expect(closeTo(result.x(), face_point.x(), TOLERANCE));
        try std.testing.expect(closeTo(result.y(), face_point.y(), TOLERANCE));
    }
}
