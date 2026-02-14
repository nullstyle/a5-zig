const std = @import("std");

pub fn expectApproxEqFloat(actual: f64, expected: f64, tolerance: f64) !void {
    try std.testing.expect(@abs(actual - expected) <= tolerance);
}

pub fn expectApproxEqFloat32(actual: f32, expected: f32, tolerance: f32) !void {
    try std.testing.expect(@abs(actual - expected) <= tolerance);
}

pub fn expectSliceApproxEqFloat(actual: []const f64, expected: []const f64, tolerance: f64) !void {
    try std.testing.expectEqual(actual.len, expected.len);
    for (actual, 0..) |actual_value, i| {
        try expectApproxEqFloat(actual_value, expected[i], tolerance);
    }
}

pub fn expectSliceApproxEqFloat32(actual: []const f32, expected: []const f32, tolerance: f32) !void {
    try std.testing.expectEqual(actual.len, expected.len);
    for (actual, 0..) |actual_value, i| {
        try expectApproxEqFloat32(actual_value, expected[i], tolerance);
    }
}
