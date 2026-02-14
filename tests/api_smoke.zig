const std = @import("std");
const a5 = @import("a5");

test "root public api smoke" {
    const world = try a5.lonlat_to_cell(a5.LonLat.new(0.0, 0.0), -1);
    try std.testing.expectEqual(@as(u64, 0), world);
    try std.testing.expectEqual(@as(i32, -1), a5.get_resolution(world));

    const world_center = try a5.cell_to_lonlat(world);
    try std.testing.expectEqual(@as(f64, 0.0), world_center.longitude());
    try std.testing.expectEqual(@as(f64, 0.0), world_center.latitude());

    const world_boundary = try a5.cell_to_boundary(std.testing.allocator, world, null);
    defer std.testing.allocator.free(world_boundary);
    try std.testing.expectEqual(@as(usize, 0), world_boundary.len);

    const world_hex = try a5.u64_to_hex(std.testing.allocator, world);
    defer std.testing.allocator.free(world_hex);
    try std.testing.expectEqualStrings("0", world_hex);
    try std.testing.expectEqual(world, try a5.hex_to_u64(world_hex));

    try std.testing.expectEqual(@as(u64, 12), a5.get_num_cells(0));
    try std.testing.expect(a5.cell_area(0) > 0.0);

    const res0_cells = try a5.get_res0_cells(std.testing.allocator);
    defer std.testing.allocator.free(res0_cells);
    try std.testing.expectEqual(@as(usize, 12), res0_cells.len);

    const compact_empty = try a5.compact(std.testing.allocator, &[_]u64{});
    defer std.testing.allocator.free(compact_empty);
    try std.testing.expectEqual(@as(usize, 0), compact_empty.len);

    const uncompact_world = try a5.uncompact(std.testing.allocator, &[_]u64{world}, 0);
    defer std.testing.allocator.free(uncompact_world);
    try std.testing.expectEqual(@as(usize, 12), uncompact_world.len);

    _ = a5.Degrees.new_unchecked(1.0);
    _ = a5.Radians.new_unchecked(1.0);
    _ = a5.A5Cell{
        .origin_id = 0,
        .segment = 0,
        .s = 0,
        .resolution = 0,
    };
}
