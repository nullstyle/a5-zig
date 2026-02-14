const std = @import("std");
const a5 = @import("a5");
const support = @import("a5_test_support");
const support_fixtures = support.fixtures;
const coordinate_systems = a5.coordinate_systems;
const authalic = a5.projections.authalic;

const TestCase = struct {
    input: f64,
    expected: f64,
};

const Fixture = struct {
    forward: []TestCase,
    inverse: []TestCase,
};

const TOLERANCE = 1e-10;
const ROUND_TRIP_TOLERANCE = 1e-15;

fn closeTo(a: f64, b: f64, tolerance: f64) bool {
    return @abs(a - b) < tolerance;
}

test "authalic forward projection matches fixture data" {
    var parsed = try support_fixtures.parseFixture(Fixture, "authalic.json", std.testing.allocator);
    defer parsed.deinit();
    const fixture = parsed.value;
    const p = authalic.AuthalicProjection{};

    for (fixture.forward) |case| {
        const actual = p.forward(coordinate_systems.Radians.new_unchecked(case.input));
        try std.testing.expect(closeTo(actual.get(), case.expected, TOLERANCE));
    }
}

test "authalic inverse projection matches fixture data" {
    var parsed = try support_fixtures.parseFixture(Fixture, "authalic.json", std.testing.allocator);
    defer parsed.deinit();
    const fixture = parsed.value;
    const p = authalic.AuthalicProjection{};

    for (fixture.inverse) |case| {
        const actual = p.inverse(coordinate_systems.Radians.new_unchecked(case.input));
        try std.testing.expect(closeTo(actual.get(), case.expected, TOLERANCE));
    }
}

test "authalic forward round trip" {
    var parsed = try support_fixtures.parseFixture(Fixture, "authalic.json", std.testing.allocator);
    defer parsed.deinit();
    const fixture = parsed.value;
    const p = authalic.AuthalicProjection{};

    for (fixture.forward) |case| {
        const as_authalic = p.forward(coordinate_systems.Radians.new_unchecked(case.input));
        const recovered = p.inverse(as_authalic);
        try std.testing.expect(closeTo(recovered.get(), case.input, ROUND_TRIP_TOLERANCE));
    }
}

test "authalic inverse round trip" {
    var parsed = try support_fixtures.parseFixture(Fixture, "authalic.json", std.testing.allocator);
    defer parsed.deinit();
    const fixture = parsed.value;
    const p = authalic.AuthalicProjection{};

    for (fixture.inverse) |case| {
        const as_geodetic = p.inverse(coordinate_systems.Radians.new_unchecked(case.input));
        const recovered = p.forward(as_geodetic);
        try std.testing.expect(closeTo(recovered.get(), case.input, ROUND_TRIP_TOLERANCE));
    }
}
