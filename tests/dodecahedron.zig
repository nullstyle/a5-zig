const std = @import("std");
const a5 = @import("a5");
const support = @import("a5_test_support");
const support_fixtures = support.fixtures;

const coordinate_systems = a5.coordinate_systems;
const dodecahedron = a5.projections.dodecahedron;

const Face = coordinate_systems.Face;
const Radians = coordinate_systems.Radians;
const Spherical = coordinate_systems.Spherical;

const ForwardCase = struct {
    input: [2]f64,
    expected: [2]f64,
};

const InverseCase = struct {
    input: [2]f64,
    expected: [2]f64,
};

const StaticData = struct {
    ORIGIN_ID: u8,
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

test "dodecahedron forward projection matches fixture data" {
    var parsed = try support_fixtures.parseFixture(Fixture, "dodecahedron-test-data.json", std.testing.allocator);
    defer parsed.deinit();
    const fixture = parsed.value;
    const origin_id = fixture.@"static".ORIGIN_ID;

    var projection = try dodecahedron.DodecahedronProjection.new();
    for (fixture.forward) |case| {
        const spherical = Spherical.new(
            Radians.new_unchecked(case.input[0]),
            Radians.new_unchecked(case.input[1]),
        );
        const result = try projection.forward(spherical, origin_id);
        try std.testing.expect(closeTo(result.x(), case.expected[0], TOLERANCE));
        try std.testing.expect(closeTo(result.y(), case.expected[1], TOLERANCE));
    }
}

test "dodecahedron inverse projection matches fixture data" {
    var parsed = try support_fixtures.parseFixture(Fixture, "dodecahedron-test-data.json", std.testing.allocator);
    defer parsed.deinit();
    const fixture = parsed.value;
    const origin_id = fixture.@"static".ORIGIN_ID;

    var projection = try dodecahedron.DodecahedronProjection.new();
    for (fixture.inverse) |case| {
        const face = Face.new(case.input[0], case.input[1]);
        const result = try projection.inverse(face, origin_id);
        try std.testing.expect(closeTo(result.theta().get(), case.expected[0], TOLERANCE));
        try std.testing.expect(closeTo(result.phi().get(), case.expected[1], TOLERANCE));
    }
}

test "dodecahedron forward round trip" {
    var parsed = try support_fixtures.parseFixture(Fixture, "dodecahedron-test-data.json", std.testing.allocator);
    defer parsed.deinit();
    const fixture = parsed.value;
    const origin_id = fixture.@"static".ORIGIN_ID;

    var projection = try dodecahedron.DodecahedronProjection.new();
    const sample_count = @min(@as(usize, 20), fixture.forward.len);
    var i: usize = 0;
    while (i < sample_count) : (i += 1) {
        const case = fixture.forward[i];
        const spherical = Spherical.new(
            Radians.new_unchecked(case.input[0]),
            Radians.new_unchecked(case.input[1]),
        );

        const face = try projection.forward(spherical, origin_id);
        const result = try projection.inverse(face, origin_id);
        try std.testing.expect(closeTo(result.theta().get(), spherical.theta().get(), TOLERANCE));
        try std.testing.expect(closeTo(result.phi().get(), spherical.phi().get(), TOLERANCE));
    }
}

test "dodecahedron inverse round trip" {
    var parsed = try support_fixtures.parseFixture(Fixture, "dodecahedron-test-data.json", std.testing.allocator);
    defer parsed.deinit();
    const fixture = parsed.value;
    const origin_id = fixture.@"static".ORIGIN_ID;

    var projection = try dodecahedron.DodecahedronProjection.new();
    const sample_count = @min(@as(usize, 20), fixture.inverse.len);
    var i: usize = 0;
    while (i < sample_count) : (i += 1) {
        const case = fixture.inverse[i];
        const face = Face.new(case.input[0], case.input[1]);
        const spherical = try projection.inverse(face, origin_id);
        const result = try projection.forward(spherical, origin_id);
        try std.testing.expect(closeTo(result.x(), face.x(), TOLERANCE));
        try std.testing.expect(closeTo(result.y(), face.y(), TOLERANCE));
    }
}

test "dodecahedron returns invalid origin errors" {
    var projection = try dodecahedron.DodecahedronProjection.new();
    const spherical = Spherical.new(
        Radians.new_unchecked(0.0),
        Radians.new_unchecked(0.0),
    );
    try std.testing.expectError(
        dodecahedron.DodecahedronProjection.Error.InvalidOriginId,
        projection.forward(spherical, 255),
    );

    const face = Face.new(0.0, 0.0);
    try std.testing.expectError(
        dodecahedron.DodecahedronProjection.Error.InvalidOriginId,
        projection.inverse(face, 255),
    );
}
