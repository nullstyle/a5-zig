const std = @import("std");
const a5 = @import("a5");
const support = @import("a5_test_support");
const support_fixtures = support.fixtures;

const coordinate_systems = a5.coordinate_systems;
const ct = a5.core.coordinate_transforms;
const origin = a5.core.origin;
const vector = a5.utils.vector;

const TOLERANCE = 1e-10;

const OriginFixture = struct {
    id: u8,
    axis: [2]f64,
    quat: [4]f64,
    angle: f64,
    orientation: [5][]const u8,
    firstQuintant: usize,
};

fn loadFixture() !std.json.Parsed([]const OriginFixture) {
    return support_fixtures.parseFixture([]const OriginFixture, "origins.json", std.testing.allocator);
}

fn quatLength(q: [4]f64) f64 {
    return std.math.sqrt((q[0] * q[0]) + (q[1] * q[1]) + (q[2] * q[2]) + (q[3] * q[3]));
}

test "origins count should be 12" {
    const origins = origin.get_origins();
    try std.testing.expectEqual(@as(usize, 12), origins.len);
}

test "origins should match fixture data" {
    var parsed = try loadFixture();
    defer parsed.deinit();
    const fixture = parsed.value;

    const origins = origin.get_origins();
    try std.testing.expectEqual(origins.len, fixture.len);

    for (origins, 0..) |origin_data, i| {
        const expected = fixture[i];
        const fixture_axis = expected.axis;
        const fixture_quat = expected.quat;

        try std.testing.expectEqual(@as(u8, @intCast(origin_data.id)), expected.id);
        try std.testing.expect(std.math.approxEqAbs(f64, origin_data.axis.theta().get(), fixture_axis[0], TOLERANCE));
        try std.testing.expect(std.math.approxEqAbs(f64, origin_data.axis.phi().get(), fixture_axis[1], TOLERANCE));
        try std.testing.expect(std.math.approxEqAbs(f64, origin_data.angle.get(), expected.angle, TOLERANCE));
        try std.testing.expectEqual(@as(usize, 5), expected.orientation.len);
        try std.testing.expectEqual(origin_data.first_quintant, expected.firstQuintant);

        for (fixture_quat, 0..) |component, j| {
            try std.testing.expect(std.math.approxEqAbs(f64, origin_data.quat[j], component, TOLERANCE));
        }
    }
}

test "origin axis should be unit vectors and quaternions should be normalized" {
    const origins = origin.get_origins();
    for (origins) |origin_data| {
        const cartesian = ct.to_cartesian(origin_data.axis);
        const axis_length = vector.vec3_length(cartesian);
        const quat_length = quatLength(origin_data.quat);

        try std.testing.expect(std.math.approxEqAbs(f64, axis_length, 1.0, TOLERANCE));
        try std.testing.expect(std.math.approxEqAbs(f64, quat_length, 1.0, TOLERANCE));
    }
}

test "find_nearest_origin should resolve origin axes" {
    const origins = origin.get_origins();
    for (origins) |origin_data| {
        const nearest = origin.find_nearest_origin(origin_data.axis);
        try std.testing.expectEqual(origin_data.id, nearest.id);
    }
}

test "boundary points should map to deterministic origin ids" {
    const boundary_points = [_]struct { point: coordinate_systems.Spherical, expected: u8 }{
        .{ .point = coordinate_systems.Spherical.new(
            coordinate_systems.Radians.new_unchecked(0.0),
            coordinate_systems.Radians.new_unchecked(a5.core.PI_OVER_5.get() / 2.0),
        ), .expected = 0 },
        .{ .point = coordinate_systems.Spherical.new(
            coordinate_systems.Radians.new_unchecked(2.0 * a5.core.PI_OVER_5.get()),
            coordinate_systems.Radians.new_unchecked(a5.core.PI_OVER_5.get()),
        ), .expected = 4 },
        .{ .point = coordinate_systems.Spherical.new(
            coordinate_systems.Radians.new_unchecked(0.0),
            coordinate_systems.Radians.new_unchecked(std.math.pi - (a5.core.PI_OVER_5.get() / 2.0)),
        ), .expected = 9 },
    };

    for (boundary_points) |case| {
        const nearest = origin.find_nearest_origin(case.point);
        try std.testing.expectEqual(case.expected, nearest.id);
    }
}

test "antipodal points should map to a different origin" {
    const origins = origin.get_origins();
    for (origins) |origin_data| {
        const antipodal = coordinate_systems.Spherical.new(
            coordinate_systems.Radians.new_unchecked(origin_data.axis.theta().get() + std.math.pi),
            coordinate_systems.Radians.new_unchecked(std.math.pi - origin_data.axis.phi().get()),
        );
        const nearest = origin.find_nearest_origin(antipodal);
        try std.testing.expect(nearest.id != origin_data.id);
    }
}

test "haversine should be zero for identical points" {
    const point1 = coordinate_systems.Spherical.new(
        coordinate_systems.Radians.new_unchecked(0.0),
        coordinate_systems.Radians.new_unchecked(0.0),
    );
    const point2 = coordinate_systems.Spherical.new(
        coordinate_systems.Radians.new_unchecked(std.math.pi / 4.0),
        coordinate_systems.Radians.new_unchecked(std.math.pi / 3.0),
    );

    try std.testing.expectEqual(@as(f64, 0.0), origin.haversine(point1, point1));
    try std.testing.expectEqual(@as(f64, 0.0), origin.haversine(point2, point2));
}

test "haversine should be symmetric and monotonic with angle separation" {
    const origin_a = coordinate_systems.Spherical.new(
        coordinate_systems.Radians.new_unchecked(0.0),
        coordinate_systems.Radians.new_unchecked(0.0),
    );
    const origin_b = coordinate_systems.Spherical.new(
        coordinate_systems.Radians.new_unchecked(std.math.pi / 2.0),
        coordinate_systems.Radians.new_unchecked(std.math.pi / 4.0),
    );

    const d1 = origin.haversine(origin_a, origin_b);
    const d2 = origin.haversine(origin_b, origin_a);
    try std.testing.expect(std.math.approxEqAbs(f64, d1, d2, TOLERANCE));

    const points = [_]coordinate_systems.Spherical{
        coordinate_systems.Spherical.new(
            coordinate_systems.Radians.new_unchecked(0.0),
            coordinate_systems.Radians.new_unchecked(std.math.pi / 6.0),
        ),
        coordinate_systems.Spherical.new(
            coordinate_systems.Radians.new_unchecked(0.0),
            coordinate_systems.Radians.new_unchecked(std.math.pi / 4.0),
        ),
        coordinate_systems.Spherical.new(
            coordinate_systems.Radians.new_unchecked(0.0),
            coordinate_systems.Radians.new_unchecked(std.math.pi / 3.0),
        ),
        coordinate_systems.Spherical.new(
            coordinate_systems.Radians.new_unchecked(0.0),
            coordinate_systems.Radians.new_unchecked(std.math.pi / 2.0),
        ),
    };

    var i: usize = 1;
    var previous = origin.haversine(origin_a, points[0]);
    while (i < points.len) : (i += 1) {
        const distance = origin.haversine(origin_a, points[i]);
        try std.testing.expect(distance > previous);
        previous = distance;
    }
}

test "haversine should increase with longitude separation" {
    const origin_point = coordinate_systems.Spherical.new(
        coordinate_systems.Radians.new_unchecked(0.0),
        coordinate_systems.Radians.new_unchecked(std.math.pi / 4.0),
    );
    const point_pi = coordinate_systems.Spherical.new(
        coordinate_systems.Radians.new_unchecked(std.math.pi),
        coordinate_systems.Radians.new_unchecked(std.math.pi / 4.0),
    );
    const point_pi_over_2 = coordinate_systems.Spherical.new(
        coordinate_systems.Radians.new_unchecked(std.math.pi / 2.0),
        coordinate_systems.Radians.new_unchecked(std.math.pi / 4.0),
    );

    const d1 = origin.haversine(origin_point, point_pi);
    const d2 = origin.haversine(origin_point, point_pi_over_2);

    try std.testing.expect(d1 > d2);
}

test "haversine should have known values" {
    const cases = [_]struct {
        p1: coordinate_systems.Spherical,
        p2: coordinate_systems.Spherical,
        expected: f64,
    }{
        .{
            .p1 = coordinate_systems.Spherical.new(
                coordinate_systems.Radians.new_unchecked(0.0),
                coordinate_systems.Radians.new_unchecked(0.0),
            ),
            .p2 = coordinate_systems.Spherical.new(
                coordinate_systems.Radians.new_unchecked(0.0),
                coordinate_systems.Radians.new_unchecked(std.math.pi / 2.0),
            ),
            .expected = 0.5,
        },
        .{
            .p1 = coordinate_systems.Spherical.new(
                coordinate_systems.Radians.new_unchecked(0.0),
                coordinate_systems.Radians.new_unchecked(std.math.pi / 4.0),
            ),
            .p2 = coordinate_systems.Spherical.new(
                coordinate_systems.Radians.new_unchecked(std.math.pi / 2.0),
                coordinate_systems.Radians.new_unchecked(std.math.pi / 4.0),
            ),
            .expected = 0.25,
        },
    };

    for (cases) |case| {
        try std.testing.expect(std.math.approxEqAbs(f64, origin.haversine(case.p1, case.p2), case.expected, 1e-4));
    }
}

test "quintant conversion should round-trip for sample origin" {
    const sample = origin.get_origins()[0];
    for (0..5) |quintant| {
        const as_segment = origin.quintant_to_segment(quintant, sample);
        const back = origin.segment_to_quintant(as_segment.segment, sample);
        try std.testing.expectEqual(@as(usize, quintant), back.quintant);
    }
}

test "is_nearest_origin should be false on face centers and boundary points" {
    const origins = origin.get_origins();
    for (origins) |origin_data| {
        try std.testing.expect(!origin.is_nearest_origin(origin_data.axis, origin_data));
    }

    const boundary_points = [_]struct { point: coordinate_systems.Spherical, expected: u8 }{
        .{ .point = coordinate_systems.Spherical.new(
            coordinate_systems.Radians.new_unchecked(0.0),
            coordinate_systems.Radians.new_unchecked(a5.core.PI_OVER_5.get() / 2.0),
        ), .expected = 0 },
        .{ .point = coordinate_systems.Spherical.new(
            coordinate_systems.Radians.new_unchecked(2.0 * a5.core.PI_OVER_5.get()),
            coordinate_systems.Radians.new_unchecked(a5.core.PI_OVER_5.get()),
        ), .expected = 4 },
        .{ .point = coordinate_systems.Spherical.new(
            coordinate_systems.Radians.new_unchecked(0.0),
            coordinate_systems.Radians.new_unchecked(std.math.pi - (a5.core.PI_OVER_5.get() / 2.0)),
        ), .expected = 9 },
    };

    for (boundary_points) |case| {
        const nearest = origin.find_nearest_origin(case.point);
        try std.testing.expect(!origin.is_nearest_origin(case.point, nearest));
        try std.testing.expectEqual(case.expected, nearest.id);
    }
}
