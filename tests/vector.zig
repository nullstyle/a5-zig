const std = @import("std");
const a5 = @import("a5");
const cartesian = a5.coordinate_systems.Cartesian;
const vector = a5.utils.vector;

fn closeTo(actual: f64, expected: f64, tolerance: f64) bool {
    return @abs(actual - expected) < tolerance;
}

fn closeToArray(a: cartesian, b: [3]f64, tolerance: f64) bool {
    return closeTo(a.x(), b[0], tolerance) and
        closeTo(a.y(), b[1], tolerance) and
        closeTo(a.z(), b[2], tolerance);
}

fn normalizeVector(v: cartesian) cartesian {
    const len = std.math.sqrt(v.x() * v.x() + v.y() * v.y() + v.z() * v.z());
    if (len == 0.0) {
        return v;
    }
    return cartesian.new(v.x() / len, v.y() / len, v.z() / len);
}

test "vector difference for identical vectors is zero" {
    const a = cartesian.new(1.0, 0.0, 0.0);
    const b = cartesian.new(1.0, 0.0, 0.0);
    const result = vector.vector_difference(a, b);
    try std.testing.expect(closeTo(result, 0.0, 1e-6));
}

test "vector difference for perpendicular vectors" {
    const a = cartesian.new(1.0, 0.0, 0.0);
    const b = cartesian.new(0.0, 1.0, 0.0);
    const result = vector.vector_difference(a, b);
    try std.testing.expect(closeTo(result, std.math.sqrt(0.5), 1e-6));
}

test "vector difference for small angles" {
    const a = cartesian.new(1.0, 0.0, 0.0);
    const b = normalizeVector(cartesian.new(0.999, 0.001, 0.0));
    const result = vector.vector_difference(a, b);
    try std.testing.expect(result > 0.0);
    try std.testing.expect(result < 0.1);
}

test "quadruple product returns finite vector" {
    const a = cartesian.new(1.0, 0.0, 0.0);
    const b = cartesian.new(0.0, 1.0, 0.0);
    const c = cartesian.new(0.0, 0.0, 1.0);
    const d = normalizeVector(cartesian.new(1.0, 1.0, 1.0));

    const result = vector.quadruple_product(a, b, c, d);
    try std.testing.expect(std.math.isFinite(result.x()));
    try std.testing.expect(std.math.isFinite(result.y()));
    try std.testing.expect(std.math.isFinite(result.z()));
}

test "quadruple product of orthogonal vectors is non-zero" {
    const a = cartesian.new(1.0, 0.0, 0.0);
    const b = cartesian.new(0.0, 1.0, 0.0);
    const c = cartesian.new(0.0, 0.0, 1.0);
    const d = cartesian.new(1.0, 0.0, 0.0);

    const result = vector.quadruple_product(a, b, c, d);
    try std.testing.expect(result.x() != 0.0 or result.y() != 0.0 or result.z() != 0.0);
}

test "slerp interpolation" {
    const a = cartesian.new(1.0, 0.0, 0.0);
    const b = cartesian.new(0.0, 1.0, 0.0);
    const result = vector.slerp(a, b, 0.5);
    const expected = [3]f64{ 1.0 / std.math.sqrt(2.0), 1.0 / std.math.sqrt(2.0), 0.0 };
    try std.testing.expect(closeToArray(result, expected, 1e-6));
}

test "slerp with t=0 returns first vector" {
    const a = cartesian.new(1.0, 0.0, 0.0);
    const b = cartesian.new(0.0, 1.0, 0.0);
    const result = vector.slerp(a, b, 0.0);
    const expected = [_]f64{ 1.0, 0.0, 0.0 };
    try std.testing.expect(closeToArray(result, expected, 1e-6));
}

test "slerp with t=1 returns second vector" {
    const a = cartesian.new(1.0, 0.0, 0.0);
    const b = cartesian.new(0.0, 1.0, 0.0);
    const result = vector.slerp(a, b, 1.0);
    const expected = [_]f64{ 0.0, 1.0, 0.0 };
    try std.testing.expect(closeToArray(result, expected, 1e-6));
}

test "slerp for identical vectors" {
    const a = cartesian.new(1.0, 0.0, 0.0);
    const b = cartesian.new(1.0, 0.0, 0.0);
    const result = vector.slerp(a, b, 0.5);
    const expected = [_]f64{ 1.0, 0.0, 0.0 };
    try std.testing.expect(closeToArray(result, expected, 1e-6));
}

test "slerp values lean toward the interpolation endpoint" {
    const a = cartesian.new(1.0, 0.0, 0.0);
    const b = cartesian.new(0.0, 1.0, 0.0);

    const result1 = vector.slerp(a, b, 0.25);
    const result2 = vector.slerp(a, b, 0.75);

    try std.testing.expect(result1.x() > result1.y());
    try std.testing.expect(result2.y() > result2.x());
}
