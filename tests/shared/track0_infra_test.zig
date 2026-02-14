const std = @import("std");
const a5 = @import("a5");
const support = @import("a5_test_support");

test "track-0 module map includes expected top-level namespaces" {
    try std.testing.expect(@hasDecl(a5, "coordinate_systems"));
    try std.testing.expect(@hasDecl(a5, "core"));
    try std.testing.expect(@hasDecl(a5, "geometry"));
    try std.testing.expect(@hasDecl(a5, "projections"));
    try std.testing.expect(@hasDecl(a5, "utils"));
    try std.testing.expect(@hasDecl(a5, "module_map"));
}

test "track-0 fixtures helper can load JSON from shared path" {
    var parsed = try support.fixtures.parseFixture([][]const u8, "test-ids.json", std.testing.allocator);
    defer parsed.deinit();
    const ids = parsed.value;
    try std.testing.expect(ids.len > 0);
    try std.testing.expectEqualStrings(ids[0], "b400000002800000");
}

test "track-0 assertions helper uses stable tolerance checks" {
    try support.assertions.expectApproxEqFloat(1.0, 1.0, 1e-12);
    try support.assertions.expectApproxEqFloat32(1.0, 1.000001, 1e-3);

    const actual_f64 = [_]f64{ 1.0, 2.0, 3.0 };
    const expected_f64 = [_]f64{ 1.0, 2.0000001, 3.0 };
    try support.assertions.expectSliceApproxEqFloat(&actual_f64, &expected_f64, 1e-6);

    const actual_f32 = [_]f32{ 1.0, 2.0, 3.0 };
    const expected_f32 = [_]f32{ 1.0, 2.0, 2.999999 };
    try support.assertions.expectSliceApproxEqFloat32(&actual_f32, &expected_f32, 1e-3);
}
