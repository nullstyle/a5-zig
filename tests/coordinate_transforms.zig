const std = @import("std");
const a5 = @import("a5");
const coordinate_systems = a5.coordinate_systems;
const ct = a5.core.coordinate_transforms;

const TOLERANCE = 1e-10;

fn closeTo(a: f64, b: f64, tolerance: f64) bool {
    return @abs(a - b) < tolerance;
}

test "angle conversion round trip" {
    try std.testing.expect(closeTo(ct.deg_to_rad(coordinate_systems.Degrees.new_unchecked(180.0)).get(), std.math.pi, TOLERANCE));
    try std.testing.expect(closeTo(ct.deg_to_rad(coordinate_systems.Degrees.new_unchecked(90.0)).get(), std.math.pi / 2.0, TOLERANCE));
    try std.testing.expect(closeTo(ct.deg_to_rad(coordinate_systems.Degrees.new_unchecked(0.0)).get(), 0.0, TOLERANCE));

    try std.testing.expect(closeTo(ct.rad_to_deg(coordinate_systems.Radians.new_unchecked(std.math.pi)).get(), 180.0, TOLERANCE));
    try std.testing.expect(closeTo(ct.rad_to_deg(coordinate_systems.Radians.new_unchecked(std.math.pi / 2.0)).get(), 90.0, TOLERANCE));
    try std.testing.expect(closeTo(ct.rad_to_deg(coordinate_systems.Radians.new_unchecked(0.0)).get(), 0.0, TOLERANCE));
}

test "polar and face conversion" {
    const test_cases = [_]struct { coordinate_systems.Face, coordinate_systems.Polar }{
        .{ coordinate_systems.Face.new(0.0, 0.0), coordinate_systems.Polar.new(0.0, coordinate_systems.Radians.new_unchecked(0.0)) },
        .{ coordinate_systems.Face.new(1.0, 0.0), coordinate_systems.Polar.new(1.0, coordinate_systems.Radians.new_unchecked(0.0)) },
        .{ coordinate_systems.Face.new(0.0, 1.0), coordinate_systems.Polar.new(1.0, coordinate_systems.Radians.new_unchecked(std.math.pi / 2.0)) },
        .{ coordinate_systems.Face.new(-1.0, 0.0), coordinate_systems.Polar.new(1.0, coordinate_systems.Radians.new_unchecked(std.math.pi)) },
    };

    for (test_cases) |case| {
        const face = case[0];
        const expected_polar = case[1];

        const actual_polar = ct.to_polar(face);
        try std.testing.expect(closeTo(actual_polar.rho(), expected_polar.rho(), TOLERANCE));
        try std.testing.expect(closeTo(actual_polar.gamma().get(), expected_polar.gamma().get(), TOLERANCE));

        const back = ct.to_face(actual_polar);
        try std.testing.expect(closeTo(back.x(), face.x(), TOLERANCE));
        try std.testing.expect(closeTo(back.y(), face.y(), TOLERANCE));
    }
}

test "barycentric conversion round trip" {
    const triangle = coordinate_systems.FaceTriangle.new(
        coordinate_systems.Face.new(0.0, 0.0),
        coordinate_systems.Face.new(1.0, 0.0),
        coordinate_systems.Face.new(0.0, 1.0),
    );

    const expected = [_]coordinate_systems.Barycentric{
        coordinate_systems.Barycentric.new(1.0, 0.0, 0.0),
        coordinate_systems.Barycentric.new(0.0, 1.0, 0.0),
        coordinate_systems.Barycentric.new(0.0, 0.0, 1.0),
    };

    const vertices = [_]coordinate_systems.Face{
        triangle.a,
        triangle.b,
        triangle.c,
    };

    for (vertices, 0..) |vertex, i| {
        const bary = ct.face_to_barycentric(vertex, triangle);
        const expected_bary = expected[i];
        try std.testing.expect(closeTo(bary.u, expected_bary.u, TOLERANCE));
        try std.testing.expect(closeTo(bary.v, expected_bary.v, TOLERANCE));
        try std.testing.expect(closeTo(bary.w, expected_bary.w, TOLERANCE));

        const round_trip = ct.barycentric_to_face(bary, triangle);
        try std.testing.expect(closeTo(round_trip.x(), vertex.x(), TOLERANCE));
        try std.testing.expect(closeTo(round_trip.y(), vertex.y(), TOLERANCE));
    }
}

test "spherical to cartesian and back" {
    const north = ct.to_cartesian(coordinate_systems.Spherical.new(
        coordinate_systems.Radians.new_unchecked(0.0),
        coordinate_systems.Radians.new_unchecked(0.0),
    ));
    try std.testing.expect(closeTo(north.x(), 0.0, TOLERANCE));
    try std.testing.expect(closeTo(north.y(), 0.0, TOLERANCE));
    try std.testing.expect(closeTo(north.z(), 1.0, TOLERANCE));

    const equator_0 = ct.to_cartesian(coordinate_systems.Spherical.new(
        coordinate_systems.Radians.new_unchecked(0.0),
        coordinate_systems.Radians.new_unchecked(std.math.pi / 2.0),
    ));
    try std.testing.expect(closeTo(equator_0.x(), 1.0, TOLERANCE));
    try std.testing.expect(closeTo(equator_0.y(), 0.0, TOLERANCE));
    try std.testing.expect(closeTo(equator_0.z(), 0.0, TOLERANCE));

    const original = coordinate_systems.Spherical.new(
        coordinate_systems.Radians.new_unchecked(std.math.pi / 4.0),
        coordinate_systems.Radians.new_unchecked(std.math.pi / 6.0),
    );
    const as_cartesian = ct.to_cartesian(original);
    const round_trip = ct.to_spherical(as_cartesian);
    try std.testing.expect(closeTo(round_trip.theta().get(), original.theta().get(), TOLERANCE));
    try std.testing.expect(closeTo(round_trip.phi().get(), original.phi().get(), TOLERANCE));
}

test "lonlat and spherical conversion round trip" {
    const test_points = [_]coordinate_systems.LonLat{
        coordinate_systems.LonLat.new(0.0, 0.0),
        coordinate_systems.LonLat.new(90.0, 0.0),
        coordinate_systems.LonLat.new(180.0, 0.0),
        coordinate_systems.LonLat.new(0.0, 45.0),
        coordinate_systems.LonLat.new(0.0, -45.0),
        coordinate_systems.LonLat.new(-90.0, -45.0),
        coordinate_systems.LonLat.new(180.0, 45.0),
        coordinate_systems.LonLat.new(90.0, 45.0),
        coordinate_systems.LonLat.new(0.0, 90.0),
        coordinate_systems.LonLat.new(0.0, -90.0),
        coordinate_systems.LonLat.new(123.0, 45.0),
    };

    for (test_points) |point| {
        const spherical = ct.from_lon_lat(point);
        const result = ct.to_lon_lat(spherical);
        try std.testing.expect(closeTo(result.longitude(), point.longitude(), 1e-6));
        try std.testing.expect(closeTo(result.latitude(), point.latitude(), 1e-6));
    }
}

test "face ij conversion round trip" {
    const test_faces = [_]coordinate_systems.Face{
        coordinate_systems.Face.new(0.0, 0.0),
        coordinate_systems.Face.new(1.0, 0.0),
        coordinate_systems.Face.new(0.0, 1.0),
        coordinate_systems.Face.new(1.0, 1.0),
        coordinate_systems.Face.new(-1.0, 0.5),
        coordinate_systems.Face.new(0.5, -0.7),
        coordinate_systems.Face.new(-0.3, -0.8),
    };

    for (test_faces) |face| {
        const ij = ct.face_to_ij(face);
        const back_face = ct.ij_to_face(ij);
        try std.testing.expect(closeTo(back_face.x(), face.x(), TOLERANCE));
        try std.testing.expect(closeTo(back_face.y(), face.y(), TOLERANCE));

        const roundtrip_ij = ct.face_to_ij(back_face);
        try std.testing.expect(closeTo(roundtrip_ij.x(), ij.x(), TOLERANCE));
        try std.testing.expect(closeTo(roundtrip_ij.y(), ij.y(), TOLERANCE));
    }

    const origin = coordinate_systems.Face.new(0.0, 0.0);
    const origin_ij = ct.face_to_ij(origin);
    try std.testing.expect(closeTo(origin_ij.x(), 0.0, TOLERANCE));
    try std.testing.expect(closeTo(origin_ij.y(), 0.0, TOLERANCE));
}

test "normalize longitudes keeps latitude and stabilizes antimeridian contours" {
    const simple_contour = [_]coordinate_systems.LonLat{
        coordinate_systems.LonLat.new(0.0, 0.0),
        coordinate_systems.LonLat.new(10.0, 0.0),
        coordinate_systems.LonLat.new(10.0, 10.0),
        coordinate_systems.LonLat.new(0.0, 10.0),
        coordinate_systems.LonLat.new(0.0, 0.0),
    };
    const normalized_simple = try ct.normalize_longitudes(std.testing.allocator, &simple_contour);
    defer std.testing.allocator.free(normalized_simple);
    for (normalized_simple, 0..) |point, idx| {
        try std.testing.expect(closeTo(point.longitude(), simple_contour[idx].longitude(), TOLERANCE));
        try std.testing.expect(closeTo(point.latitude(), simple_contour[idx].latitude(), TOLERANCE));
    }

    const antimeridian_contour = [_]coordinate_systems.LonLat{
        coordinate_systems.LonLat.new(179.0, 0.0),
        coordinate_systems.LonLat.new(179.5, 0.0),
        coordinate_systems.LonLat.new(-179.5, 0.0),
        coordinate_systems.LonLat.new(-179.0, 0.0),
    };
    const normalized = try ct.normalize_longitudes(std.testing.allocator, &antimeridian_contour);
    defer std.testing.allocator.free(normalized);
    for (normalized) |point| {
        try std.testing.expect(closeTo(point.latitude(), 0.0, TOLERANCE));
    }

    const normalized_again = try ct.normalize_longitudes(std.testing.allocator, normalized);
    defer std.testing.allocator.free(normalized_again);
    for (normalized, 0..) |point, idx| {
        try std.testing.expect(closeTo(point.longitude(), normalized_again[idx].longitude(), TOLERANCE));
        try std.testing.expect(closeTo(point.latitude(), normalized_again[idx].latitude(), TOLERANCE));
    }
}
