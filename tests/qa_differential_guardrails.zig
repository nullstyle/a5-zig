const std = @import("std");
const a5 = @import("a5");
const support = @import("a5_test_support");

const coordinate_systems = a5.coordinate_systems;
const ct = a5.core.coordinate_transforms;
const cell = a5.core.cell;
const compact = a5.core.compact;
const hex = a5.core.hex;
const serialization = a5.core.serialization;
const authalic = a5.projections.authalic;
const gnomonic = a5.projections.gnomonic;

const TOLERANCE: f64 = 1e-10;
const DIFF_SAMPLE_SEED: u64 = 0x00a5_7d1f_f5ee_d001;
const DRIFT_SAMPLE_SEED: u64 = 0x0077_aa5d_1f6e_ed10;

fn closeTo(a: f64, b: f64, tolerance: f64) bool {
    return @abs(a - b) <= tolerance;
}

fn wrappedLongitudeDelta(a: f64, b: f64) f64 {
    const raw = a - b;
    const shifted = raw + 180.0;
    const normalized = shifted - std.math.floor(shifted / 360.0) * 360.0;
    return normalized - 180.0;
}

fn wrappedAngleDelta(a: f64, b: f64) f64 {
    const raw = @abs(a - b);
    return @min(raw, std.math.tau - raw);
}

fn containsCell(values: []const u64, target: u64) bool {
    for (values) |value| {
        if (value == target) {
            return true;
        }
    }
    return false;
}

fn longitudeSpan(points: []const coordinate_systems.LonLat) f64 {
    if (points.len == 0) return 0.0;
    var min_lon = std.math.inf(f64);
    var max_lon = -std.math.inf(f64);
    for (points) |point| {
        min_lon = @min(min_lon, point.longitude());
        max_lon = @max(max_lon, point.longitude());
    }
    return max_lon - min_lon;
}

fn sortU64(values: []u64) void {
    if (values.len < 2) return;
    var i: usize = 0;
    while (i < values.len - 1) : (i += 1) {
        var min_index = i;
        var j: usize = i + 1;
        while (j < values.len) : (j += 1) {
            if (values[j] < values[min_index]) {
                min_index = j;
            }
        }
        if (min_index != i) {
            std.mem.swap(u64, &values[i], &values[min_index]);
        }
    }
}

fn parseHexList(allocator: std.mem.Allocator, ids: []const []const u8) ![]u64 {
    var out = try allocator.alloc(u64, ids.len);
    for (ids, 0..) |id, idx| {
        out[idx] = try hex.hex_to_u64(id);
    }
    return out;
}

const CompactFixtureCase = struct {
    name: []const u8,
    input: []const []const u8,
    @"expectedOutput": []const []const u8,
};

const CompactFixtures = struct {
    compact: []const CompactFixtureCase,
};

test "qa cross-track migration surface keeps expected modules wired" {
    try std.testing.expect(@hasDecl(a5, "coordinate_systems"));
    try std.testing.expect(@hasDecl(a5, "core"));
    try std.testing.expect(@hasDecl(a5, "geometry"));
    try std.testing.expect(@hasDecl(a5, "projections"));
    try std.testing.expect(@hasDecl(a5, "utils"));
    try std.testing.expect(@hasDecl(a5.core, "coordinate_transforms"));
    try std.testing.expect(@hasDecl(a5.core, "hilbert"));
    try std.testing.expect(@hasDecl(a5.core, "serialization"));
    try std.testing.expect(@hasDecl(a5.projections, "authalic"));
    try std.testing.expect(@hasDecl(a5.projections, "gnomonic"));
    try std.testing.expect(@hasDecl(a5.projections, "polyhedral"));
}

test "qa deterministic rust-fixture differential spot checks preserve bit-level hierarchy behavior" {
    var parsed = try support.fixtures.parseFixture([][]const u8, "test-ids.json", std.testing.allocator);
    defer parsed.deinit();
    const fixture_ids = parsed.value;

    try std.testing.expect(fixture_ids.len > 0);

    var prng = std.Random.DefaultPrng.init(DIFF_SAMPLE_SEED);
    const random = prng.random();
    const sample_size: usize = if (fixture_ids.len < 24) fixture_ids.len else 24;

    var i: usize = 0;
    while (i < sample_size) : (i += 1) {
        const fixture_index = random.uintLessThan(usize, fixture_ids.len);
        const fixture_hex = fixture_ids[fixture_index];

        const fixture_value = try hex.hex_to_u64(fixture_hex);
        const decoded_cell = try serialization.deserialize(fixture_value);
        const reserialized = try serialization.serialize(decoded_cell);
        try std.testing.expectEqual(fixture_value, reserialized);

        const reserialized_hex = try std.fmt.allocPrint(std.testing.allocator, "{x:0>16}", .{reserialized});
        defer std.testing.allocator.free(reserialized_hex);
        try std.testing.expectEqualStrings(fixture_hex, reserialized_hex);

        const resolution = serialization.get_resolution(fixture_value);
        try std.testing.expect(resolution >= -1);
        try std.testing.expect(resolution <= serialization.MAX_RESOLUTION);

        if (resolution >= 0) {
            const parent = try serialization.cell_to_parent(fixture_value, null);
            const parent_resolution = serialization.get_resolution(parent);
            try std.testing.expectEqual(resolution - 1, parent_resolution);

            const siblings = try serialization.cell_to_children(std.testing.allocator, parent, resolution);
            defer std.testing.allocator.free(siblings);
            try std.testing.expect(containsCell(siblings, fixture_value));
        }
    }
}

test "qa antimeridian and high-latitude geometry regressions stay stable" {
    const antimeridian_contour = [_]coordinate_systems.LonLat{
        coordinate_systems.LonLat.new(179.8, 85.0),
        coordinate_systems.LonLat.new(179.6, 85.2),
        coordinate_systems.LonLat.new(-179.6, 85.1),
        coordinate_systems.LonLat.new(-179.8, 84.9),
        coordinate_systems.LonLat.new(179.8, 85.0),
    };

    const normalized = try ct.normalize_longitudes(std.testing.allocator, &antimeridian_contour);
    defer std.testing.allocator.free(normalized);

    const normalized_again = try ct.normalize_longitudes(std.testing.allocator, normalized);
    defer std.testing.allocator.free(normalized_again);

    for (normalized, 0..) |point, idx| {
        try std.testing.expect(closeTo(point.latitude(), antimeridian_contour[idx].latitude(), TOLERANCE));
        try std.testing.expect(closeTo(point.longitude(), normalized_again[idx].longitude(), TOLERANCE));
        try std.testing.expect(closeTo(point.latitude(), normalized_again[idx].latitude(), TOLERANCE));
    }

    var i: usize = 1;
    while (i < normalized.len) : (i += 1) {
        const longitude_delta = @abs(normalized[i].longitude() - normalized[i - 1].longitude());
        try std.testing.expect(longitude_delta <= 180.0 + 1e-9);
    }

    const high_latitude_points = [_]coordinate_systems.LonLat{
        coordinate_systems.LonLat.new(179.999, 89.999),
        coordinate_systems.LonLat.new(-179.999, 89.999),
        coordinate_systems.LonLat.new(170.0, -89.999),
        coordinate_systems.LonLat.new(-170.0, -89.999),
        coordinate_systems.LonLat.new(45.0, 85.0),
        coordinate_systems.LonLat.new(-45.0, -85.0),
    };

    for (high_latitude_points) |point| {
        const spherical = ct.from_lon_lat(point);
        const recovered = ct.to_lon_lat(spherical);
        const lon_delta = @abs(wrappedLongitudeDelta(recovered.longitude(), point.longitude()));
        try std.testing.expect(lon_delta <= 1e-7);
        try std.testing.expect(closeTo(recovered.latitude(), point.latitude(), 1e-7));
    }
}

test "qa projection drift remains inside deterministic tolerance budgets" {
    var prng = std.Random.DefaultPrng.init(DRIFT_SAMPLE_SEED);
    const random = prng.random();

    const gnomonic_projection = gnomonic.GnomonicProjection{};
    const authalic_projection = authalic.AuthalicProjection{};
    const sample_count: usize = 256;

    var max_theta_drift: f64 = 0.0;
    var max_phi_drift: f64 = 0.0;
    var max_authalic_drift: f64 = 0.0;

    var i: usize = 0;
    while (i < sample_count) : (i += 1) {
        const theta = random.float(f64) * std.math.tau;
        const phi = random.float(f64) * ((std.math.pi / 2.0) - 2e-6) + 1e-6;
        const spherical = coordinate_systems.Spherical.new(
            coordinate_systems.Radians.new_unchecked(theta),
            coordinate_systems.Radians.new_unchecked(phi),
        );

        const projected = gnomonic_projection.forward(spherical);
        const recovered = gnomonic_projection.inverse(projected);

        max_theta_drift = @max(max_theta_drift, wrappedAngleDelta(recovered.theta().get(), theta));
        max_phi_drift = @max(max_phi_drift, @abs(recovered.phi().get() - phi));

        const geodetic_lat = (random.float(f64) * 2.0 - 1.0) * ((std.math.pi / 2.0) - 1e-6);
        const authalic_lat = authalic_projection.forward(coordinate_systems.Radians.new_unchecked(geodetic_lat));
        const geodetic_recovered = authalic_projection.inverse(authalic_lat);
        max_authalic_drift = @max(max_authalic_drift, @abs(geodetic_recovered.get() - geodetic_lat));
    }

    try std.testing.expect(max_theta_drift <= 1e-10);
    try std.testing.expect(max_phi_drift <= 1e-10);
    try std.testing.expect(max_authalic_drift <= 1e-12);
}

test "qa track-6 release gate validates public cell and compact surface" {
    try std.testing.expect(@hasDecl(a5.core, "cell"));
    try std.testing.expect(@hasDecl(a5.core, "compact"));

    try std.testing.expect(@hasDecl(a5, "cell_to_boundary"));
    try std.testing.expect(@hasDecl(a5, "cell_to_lonlat"));
    try std.testing.expect(@hasDecl(a5, "lonlat_to_cell"));
    try std.testing.expect(@hasDecl(a5, "compact"));
    try std.testing.expect(@hasDecl(a5, "uncompact"));
}

test "qa deterministic compact differential checks agree with Rust fixture expectations" {
    var parsed = try support.fixtures.parseFixture(CompactFixtures, "compact.json", std.testing.allocator);
    defer parsed.deinit();
    const fixture = parsed.value;

    try std.testing.expect(fixture.compact.len > 0);

    var prng = std.Random.DefaultPrng.init(DIFF_SAMPLE_SEED ^ 0x00c0_ac47_0000_0001);
    const random = prng.random();
    const sample_size: usize = if (fixture.compact.len < 8) fixture.compact.len else 8;

    var i: usize = 0;
    while (i < sample_size) : (i += 1) {
        const case_index = random.uintLessThan(usize, fixture.compact.len);
        const case_data = fixture.compact[case_index];
        try std.testing.expect(case_data.name.len > 0);

        const input_cells = try parseHexList(std.testing.allocator, case_data.input);
        defer std.testing.allocator.free(input_cells);

        const expected_cells = try parseHexList(std.testing.allocator, case_data.@"expectedOutput");
        defer std.testing.allocator.free(expected_cells);
        sortU64(expected_cells);

        const result = try compact.compact(std.testing.allocator, input_cells);
        defer std.testing.allocator.free(result);
        sortU64(result);

        try std.testing.expectEqual(expected_cells.len, result.len);
        for (expected_cells, result) |expected_cell, actual_cell| {
            try std.testing.expectEqual(expected_cell, actual_cell);
        }
    }
}

test "qa deterministic cell boundary and roundtrip spot checks cover antimeridian and high-latitude cases" {
    const points = [_]coordinate_systems.LonLat{
        coordinate_systems.LonLat.new(179.95, 85.0),
        coordinate_systems.LonLat.new(-179.95, 85.0),
        coordinate_systems.LonLat.new(179.95, -85.0),
        coordinate_systems.LonLat.new(-179.95, -85.0),
        coordinate_systems.LonLat.new(0.0, 89.9),
        coordinate_systems.LonLat.new(0.0, -89.9),
        coordinate_systems.LonLat.new(45.0, 0.0),
        coordinate_systems.LonLat.new(-120.0, 35.0),
    };
    const resolutions = [_]i32{ 0, 1, 2, 5 };

    for (resolutions) |resolution| {
        for (points) |point| {
            const cell_id = try cell.lonlat_to_cell(point, resolution);
            try std.testing.expectEqual(resolution, serialization.get_resolution(cell_id));

            const boundary = try cell.cell_to_boundary(std.testing.allocator, cell_id, .{
                .closed_ring = true,
                .segments = 6,
            });
            defer std.testing.allocator.free(boundary);

            try std.testing.expect(boundary.len > 0);
            try std.testing.expect(@abs(wrappedLongitudeDelta(boundary[0].longitude(), boundary[boundary.len - 1].longitude())) <= 1e-7);
            try std.testing.expect(closeTo(boundary[0].latitude(), boundary[boundary.len - 1].latitude(), 1e-7));

            const center = try cell.cell_to_lonlat(cell_id);
            const cell_data = try serialization.deserialize(cell_id);
            const containment = try cell.a5cell_contains_point(cell_data, center);
            try std.testing.expect(containment > -1e-8);
        }
    }

    const antimeridian_cells = [_][]const u8{
        "eb60000000000000",
        "2e00000000000000",
    };
    const segments = [_]i32{ 1, 10 };
    for (antimeridian_cells) |cell_hex| {
        const antimeridian_cell = try hex.hex_to_u64(cell_hex);
        for (segments) |segment_count| {
            const boundary = try cell.cell_to_boundary(std.testing.allocator, antimeridian_cell, .{
                .closed_ring = true,
                .segments = segment_count,
            });
            defer std.testing.allocator.free(boundary);
            try std.testing.expect(longitudeSpan(boundary) < 180.0);
        }
    }
}
