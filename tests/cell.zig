const std = @import("std");
const a5 = @import("a5");
const support = @import("a5_test_support");
const fixtures = support.fixtures;

const cell = a5.core.cell;
const hex = a5.core.hex;
const serialization = a5.core.serialization;
const LonLat = a5.coordinate_systems.LonLat;

const TOLERANCE: f64 = 1e-10;

fn close_to(a: f64, b: f64, tolerance: f64) bool {
    return @abs(a - b) < tolerance;
}

fn load_test_ids() !std.json.Parsed([]const []const u8) {
    return fixtures.parseFixture([]const []const u8, "test-ids.json", std.testing.allocator);
}

fn longitude_span(points: []const LonLat) f64 {
    if (points.len == 0) return 0.0;

    var min_lon = std.math.inf(f64);
    var max_lon = -std.math.inf(f64);
    for (points) |point| {
        min_lon = @min(min_lon, point.longitude());
        max_lon = @max(max_lon, point.longitude());
    }
    return max_lon - min_lon;
}

test "cell world id for resolution -1" {
    const cell_id = try cell.lonlat_to_cell(LonLat.new(0.0, 0.0), -1);
    try std.testing.expectEqual(serialization.WORLD_CELL, cell_id);
}

test "cell world center is origin lonlat" {
    const lonlat = try cell.cell_to_lonlat(serialization.WORLD_CELL);
    try std.testing.expect(close_to(lonlat.longitude(), 0.0, TOLERANCE));
    try std.testing.expect(close_to(lonlat.latitude(), 0.0, TOLERANCE));
}

test "cell world boundary is empty" {
    const boundary = try cell.cell_to_boundary(std.testing.allocator, serialization.WORLD_CELL, null);
    defer std.testing.allocator.free(boundary);
    try std.testing.expectEqual(@as(usize, 0), boundary.len);
}

test "cell antimeridian boundary longitude span stays below 180 degrees" {
    const antimeridian_cells = [_][]const u8{
        "eb60000000000000",
        "2e00000000000000",
    };
    const segments = [_]i32{ 1, 10 };

    for (antimeridian_cells) |cell_hex| {
        const cell_id = try hex.hex_to_u64(cell_hex);

        for (segments) |segment| {
            const options = cell.CellToBoundaryOptions{
                .closed_ring = true,
                .segments = segment,
            };
            const boundary = try cell.cell_to_boundary(std.testing.allocator, cell_id, options);
            defer std.testing.allocator.free(boundary);
            try std.testing.expect(longitude_span(boundary) < 180.0);
        }

        const auto_boundary = try cell.cell_to_boundary(std.testing.allocator, cell_id, null);
        defer std.testing.allocator.free(auto_boundary);
        try std.testing.expect(longitude_span(auto_boundary) < 180.0);
    }
}

test "cell boundary closed_ring option controls closure" {
    const cell_id = try hex.hex_to_u64("eb60000000000000");

    const open_options = cell.CellToBoundaryOptions{
        .closed_ring = false,
        .segments = 5,
    };
    const closed_options = cell.CellToBoundaryOptions{
        .closed_ring = true,
        .segments = 5,
    };

    const open_boundary = try cell.cell_to_boundary(std.testing.allocator, cell_id, open_options);
    defer std.testing.allocator.free(open_boundary);
    const closed_boundary = try cell.cell_to_boundary(std.testing.allocator, cell_id, closed_options);
    defer std.testing.allocator.free(closed_boundary);

    try std.testing.expect(open_boundary.len > 0);
    try std.testing.expectEqual(open_boundary.len + 1, closed_boundary.len);
    try std.testing.expect(close_to(closed_boundary[0].longitude(), closed_boundary[closed_boundary.len - 1].longitude(), TOLERANCE));
    try std.testing.expect(close_to(closed_boundary[0].latitude(), closed_boundary[closed_boundary.len - 1].latitude(), TOLERANCE));
}

test "cell centers are contained in their own cells for fixture ids sample" {
    var parsed = try load_test_ids();
    defer parsed.deinit();

    const sample_count = @min(@as(usize, 32), parsed.value.len);
    for (parsed.value[0..sample_count]) |cell_hex| {
        const cell_id = try hex.hex_to_u64(cell_hex);
        if (cell_id == serialization.WORLD_CELL) continue;

        const center = try cell.cell_to_lonlat(cell_id);
        const cell_data = try serialization.deserialize(cell_id);
        const containment = try cell.a5cell_contains_point(cell_data, center);
        try std.testing.expect(containment > -1e-8);
    }
}
