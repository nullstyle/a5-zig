const builtin = @import("builtin");
const std = @import("std");
const a5 = @import("a5");
const support = @import("a5_test_support");

const coordinate_systems = a5.coordinate_systems;
const cell = a5.core.cell;
const compact = a5.core.compact;
const ct = a5.core.coordinate_transforms;
const hex = a5.core.hex;
const serialization = a5.core.serialization;

const MEMORY_SAMPLE_SEED: u64 = 0x005e_ed5e_ed5e_ed51;

fn perfBudgetNs() i128 {
    return switch (builtin.mode) {
        .Debug => @as(i128, 40 * std.time.ns_per_s),
        .ReleaseSafe => @as(i128, 12 * std.time.ns_per_s),
        .ReleaseFast => @as(i128, 8 * std.time.ns_per_s),
        .ReleaseSmall => @as(i128, 8 * std.time.ns_per_s),
    };
}

test "qa perf smoke serialization and hierarchy loop stays within mode-aware budget" {
    var parsed = try support.fixtures.parseFixture([][]const u8, "test-ids.json", std.testing.allocator);
    defer parsed.deinit();
    const fixture_ids = parsed.value;

    try std.testing.expect(fixture_ids.len > 0);

    const parsed_count: usize = if (fixture_ids.len < 32) fixture_ids.len else 32;
    const parsed_values = try std.testing.allocator.alloc(u64, parsed_count);
    defer std.testing.allocator.free(parsed_values);

    for (parsed_values, 0..) |*slot, idx| {
        slot.* = try hex.hex_to_u64(fixture_ids[idx]);
    }

    var checksum: u64 = 0;
    const iterations: usize = 20_000;
    const start = std.time.nanoTimestamp();

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const cell_id = parsed_values[i % parsed_values.len];
        const decoded = try serialization.deserialize(cell_id);
        const encoded = try serialization.serialize(decoded);
        checksum +%= encoded ^ 0x9e3779b97f4a7c15;

        const resolution = serialization.get_resolution(cell_id);
        if (resolution >= 0) {
            const parent = try serialization.cell_to_parent(cell_id, null);
            checksum +%= parent ^ 0xc2b2ae3d27d4eb4f;
        }
    }

    const res0_cells = try serialization.cell_to_children(std.testing.allocator, serialization.WORLD_CELL, 0);
    defer std.testing.allocator.free(res0_cells);
    const antimeridian_cell = try hex.hex_to_u64("eb60000000000000");

    var j: usize = 0;
    while (j < 500) : (j += 1) {
        const compacted = try compact.compact(std.testing.allocator, res0_cells);
        defer std.testing.allocator.free(compacted);
        const uncompacted = try compact.uncompact(std.testing.allocator, compacted, 0);
        defer std.testing.allocator.free(uncompacted);

        const boundary = try cell.cell_to_boundary(std.testing.allocator, antimeridian_cell, .{
            .closed_ring = false,
            .segments = 4,
        });
        defer std.testing.allocator.free(boundary);
        checksum +%= @as(u64, @intCast(uncompacted.len + boundary.len));
    }

    const elapsed = std.time.nanoTimestamp() - start;
    try std.testing.expect(elapsed > 0);
    try std.testing.expect(elapsed <= perfBudgetNs());
    try std.testing.expect(checksum != 0);
}

test "qa memory smoke repeated antimeridian normalization leaves no allocator leaks" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const status = gpa.deinit();
        std.debug.assert(status == .ok);
    }

    const allocator = gpa.allocator();
    var prng = std.Random.DefaultPrng.init(MEMORY_SAMPLE_SEED);
    const random = prng.random();

    var contour: [64]coordinate_systems.LonLat = undefined;
    for (&contour) |*point| {
        const base_lon: f64 = if (random.float(f64) < 0.5) 179.0 else -179.0;
        const longitude = base_lon + (random.float(f64) - 0.5) * 0.9;
        const latitude = 80.0 + random.float(f64) * 9.8;
        point.* = coordinate_systems.LonLat.new(longitude, latitude);
    }

    var i: usize = 0;
    while (i < 2_000) : (i += 1) {
        const normalized = try ct.normalize_longitudes(allocator, &contour);
        allocator.free(normalized);
    }

    const res0_cells = try serialization.cell_to_children(allocator, serialization.WORLD_CELL, 0);
    defer allocator.free(res0_cells);
    const antimeridian_cell = try hex.hex_to_u64("eb60000000000000");

    var j: usize = 0;
    while (j < 400) : (j += 1) {
        const compacted = try compact.compact(allocator, res0_cells);
        defer allocator.free(compacted);
        const uncompacted = try compact.uncompact(allocator, compacted, 0);
        defer allocator.free(uncompacted);
        const boundary = try cell.cell_to_boundary(allocator, antimeridian_cell, .{
            .closed_ring = true,
            .segments = 5,
        });
        defer allocator.free(boundary);
    }
}
