const std = @import("std");
const a5 = @import("a5");
const support = @import("a5_test_support");
const support_fixtures = support.fixtures;
const coordinate_systems = a5.coordinate_systems;
const gnomonic = a5.projections.gnomonic;

const FixtureCase = struct {
    input: [2]f64,
    expected: [2]f64,
};

const Fixture = struct {
    forward: []FixtureCase,
    inverse: []FixtureCase,
};

const TOLERANCE: f64 = 1e-10;

fn closeTo(a: f64, b: f64, tolerance: f64) bool {
    return @abs(a - b) < tolerance;
}

fn closeToPolar(a: coordinate_systems.Polar, b: [2]f64, tolerance: f64) bool {
    return closeTo(a.rho(), b[0], tolerance) and closeTo(a.gamma().get(), b[1], tolerance);
}

fn closeToSpherical(a: coordinate_systems.Spherical, b: [2]f64, tolerance: f64) bool {
    return closeTo(a.theta().get(), b[0], tolerance) and closeTo(a.phi().get(), b[1], tolerance);
}

test "gnomonic forward projection matches fixture data" {
    var parsed = try support_fixtures.parseFixture(Fixture, "gnomonic.json", std.testing.allocator);
    defer parsed.deinit();
    const fixture = parsed.value;
    const p = gnomonic.GnomonicProjection{};

    for (fixture.forward) |case| {
        const spherical = coordinate_systems.Spherical.new(
            coordinate_systems.Radians.new_unchecked(case.input[0]),
            coordinate_systems.Radians.new_unchecked(case.input[1]),
        );
        const result = p.forward(spherical);
        try std.testing.expect(closeToPolar(result, case.expected, TOLERANCE));
    }
}

test "gnomonic inverse projection matches fixture data" {
    var parsed = try support_fixtures.parseFixture(Fixture, "gnomonic.json", std.testing.allocator);
    defer parsed.deinit();
    const fixture = parsed.value;
    const p = gnomonic.GnomonicProjection{};

    for (fixture.inverse) |case| {
        const polar = coordinate_systems.Polar.new(
            case.input[0],
            coordinate_systems.Radians.new_unchecked(case.input[1]),
        );
        const result = p.inverse(polar);
        try std.testing.expect(closeToSpherical(result, case.expected, TOLERANCE));
    }
}

test "gnomonic forward round trip" {
    var parsed = try support_fixtures.parseFixture(Fixture, "gnomonic.json", std.testing.allocator);
    defer parsed.deinit();
    const fixture = parsed.value;
    const p = gnomonic.GnomonicProjection{};

    for (fixture.forward) |case| {
        const spherical = coordinate_systems.Spherical.new(
            coordinate_systems.Radians.new_unchecked(case.input[0]),
            coordinate_systems.Radians.new_unchecked(case.input[1]),
        );
        const polar = p.forward(spherical);
        const result = p.inverse(polar);
        try std.testing.expect(closeToSpherical(result, case.input, TOLERANCE));
    }
}

test "gnomonic inverse round trip" {
    var parsed = try support_fixtures.parseFixture(Fixture, "gnomonic.json", std.testing.allocator);
    defer parsed.deinit();
    const fixture = parsed.value;
    const p = gnomonic.GnomonicProjection{};

    for (fixture.inverse) |case| {
        const polar = coordinate_systems.Polar.new(
            case.input[0],
            coordinate_systems.Radians.new_unchecked(case.input[1]),
        );
        const spherical = p.inverse(polar);
        const result = p.forward(spherical);
        try std.testing.expect(closeToPolar(result, case.input, TOLERANCE));
    }
}
