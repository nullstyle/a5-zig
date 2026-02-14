const std = @import("std");
const a5 = @import("a5");
const assertions = @import("a5_test_support").assertions;

const core_pentagon = a5.core.pentagon;
const geometry = a5.geometry.pentagon;

const TOLERANCE: f64 = 1e-10;

fn closeTo(actual: f64, expected: f64) !void {
    try assertions.expectApproxEqFloat(actual, expected, TOLERANCE);
}

test "core.pentagon.angles" {
    try closeTo(core_pentagon.A.get(), 72.0);
    try closeTo(core_pentagon.B.get(), 127.94543761193603);
    try closeTo(core_pentagon.C.get(), 108.0);
    try closeTo(core_pentagon.D.get(), 82.29202980963508);
    try closeTo(core_pentagon.E.get(), 149.7625318412527);
}

test "core.pentagon.pentagon_vertices" {
    const expected = [_][2]f64{
        .{ 0.0, 0.0 },
        .{ 0.1993818474311588, 0.3754138223914238 },
        .{ 0.6180339887498949, 0.4490279765795854 },
        .{ 0.8174158361810537, 0.0736141541881617 },
        .{ 0.418652141318736, -0.07361415418816161 },
    };

    const vertices = core_pentagon.pentagon().get_vertices();
    try std.testing.expectEqual(expected.len, 5);
    for (vertices, 0..) |actual, i| {
        try closeTo(actual.x(), expected[i][0]);
        try closeTo(actual.y(), expected[i][1]);
    }
}

test "core.pentagon.triangle_vertices" {
    const expected = [_][2]f64{
        .{ 0.0, 0.0 },
        .{ 0.6180339887498949, 0.4490279765795854 },
        .{ 0.6180339887498949, -0.4490279765795854 },
    };

    const vertices = core_pentagon.triangle().get_vertices_vec();
    try closeTo(core_pentagon.v_angle().get(), 0.6283185307179586);
    for (vertices, 0..) |actual, i| {
        try closeTo(actual.x(), expected[i][0]);
        try closeTo(actual.y(), expected[i][1]);
    }
}

test "core.pentagon.basis_matrices" {
    const expected_basis = [_]f64{
        0.6180339887498949,
        0.4490279765795854,
        0.6180339887498949,
        -0.4490279765795854,
    };
    const expected_inverse = [_]f64{
        0.8090169943749475,
        0.8090169943749475,
        1.1135163644116068,
        -1.1135163644116068,
    };

    const basis = core_pentagon.basis();
    const inverse = core_pentagon.basis_inverse();
    try closeTo(basis.m00, expected_basis[0]);
    try closeTo(basis.m10, expected_basis[1]);
    try closeTo(basis.m01, expected_basis[2]);
    try closeTo(basis.m11, expected_basis[3]);

    try closeTo(inverse.m00, expected_inverse[0]);
    try closeTo(inverse.m10, expected_inverse[1]);
    try closeTo(inverse.m01, expected_inverse[2]);
    try closeTo(inverse.m11, expected_inverse[3]);
}

test "core.pentagon.basis_matrix_is_identity" {
    const basis = core_pentagon.basis();
    const inverse = core_pentagon.basis_inverse();

    const r00 = basis.m00 * inverse.m00 + basis.m01 * inverse.m10;
    const r01 = basis.m00 * inverse.m01 + basis.m01 * inverse.m11;
    const r10 = basis.m10 * inverse.m00 + basis.m11 * inverse.m10;
    const r11 = basis.m10 * inverse.m01 + basis.m11 * inverse.m11;

    try closeTo(r00, 1.0);
    try closeTo(r01, 0.0);
    try closeTo(r10, 0.0);
    try closeTo(r11, 1.0);
}

test "core.pentagon.mat2_operations" {
    const mat = core_pentagon.Mat2.new(2.0, 1.0, 3.0, 4.0);
    try closeTo(mat.determinant(), 5.0);

    const inverse = mat.inverse().?;
    try closeTo(inverse.m00, 0.8);
    try closeTo(inverse.m01, -0.2);
    try closeTo(inverse.m10, -0.6);
    try closeTo(inverse.m11, 0.4);

    const point = a5.coordinate_systems.Face.new(1.0, 2.0);
    const transformed = mat.transform(point);
    try closeTo(transformed.x(), 4.0);
    try closeTo(transformed.y(), 11.0);
}

test "core.pentagon.singleton_behavior" {
    const a1 = core_pentagon.a();
    const a2 = core_pentagon.a();
    try std.testing.expect(a1.x() == a2.x() and a1.y() == a2.y());

    const p1 = core_pentagon.pentagon().get_vertices();
    const p2 = core_pentagon.pentagon().get_vertices();
    try std.testing.expectEqual(p1, p2);
}
