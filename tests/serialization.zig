const std = @import("std");
const support = @import("a5_test_support");
const a5 = @import("a5");

const origin = a5.core.origin;
const serialization = a5.core.serialization;
const A5Cell = a5.core.A5Cell;
const fixtures = support.fixtures;

const RESOLUTION_MASKS = [_][]const u8{
    "0000001000000000000000000000000000000000000000000000000000000000",
    "0000000100000000000000000000000000000000000000000000000000000000",
    "0000000010000000000000000000000000000000000000000000000000000000",
    "0000000000100000000000000000000000000000000000000000000000000000",
    "0000000000001000000000000000000000000000000000000000000000000000",
    "0000000000000010000000000000000000000000000000000000000000000000",
    "0000000000000000100000000000000000000000000000000000000000000000",
    "0000000000000000001000000000000000000000000000000000000000000000",
    "0000000000000000000010000000000000000000000000000000000000000000",
    "0000000000000000000000100000000000000000000000000000000000000000",
    "0000000000000000000000001000000000000000000000000000000000000000",
    "0000000000000000000000000010000000000000000000000000000000000000",
    "0000000000000000000000000000100000000000000000000000000000000000",
    "0000000000000000000000000000001000000000000000000000000000000000",
    "0000000000000000000000000000000010000000000000000000000000000000",
    "0000000000000000000000000000000000100000000000000000000000000000",
    "0000000000000000000000000000000000001000000000000000000000000000",
    "0000000000000000000000000000000000000010000000000000000000000000",
    "0000000000000000000000000000000000000000100000000000000000000000",
    "0000000000000000000000000000000000000000001000000000000000000000",
    "0000000000000000000000000000000000000000000010000000000000000000",
    "0000000000000000000000000000000000000000000000100000000000000000",
    "0000000000000000000000000000000000000000000000001000000000000000",
    "0000000000000000000000000000000000000000000000000010000000000000",
    "0000000000000000000000000000000000000000000000000000100000000000",
    "0000000000000000000000000000000000000000000000000000001000000000",
    "0000000000000000000000000000000000000000000000000000000010000000",
    "0000000000000000000000000000000000000000000000000000000000100000",
    "0000000000000000000000000000000000000000000000000000000000001000",
    "0000000000000000000000000000000000000000000000000000000000000010",
};

fn load_test_ids() !std.json.Parsed([]const []const u8) {
    return fixtures.parseFixture([]const []const u8, "test-ids.json", std.testing.allocator);
}

test "serialization.correct_number_of_masks" {
    try std.testing.expectEqual(@as(usize, @intCast(serialization.MAX_RESOLUTION)), RESOLUTION_MASKS.len);
}

test "serialization.removal_mask_is_correct" {
    const expected = (@as(u64, 1) << 58) - 1;
    try std.testing.expectEqual(expected, serialization.REMOVAL_MASK);
}

test "serialization.encodes_resolution_correctly_for_different_values" {
    const origins = origin.get_origins();
    const origin0 = origins[0];

    for (RESOLUTION_MASKS, 0..) |mask, i| {
        const cell = A5Cell{
            .origin_id = origin0.id,
            .segment = 4,
            .s = 0,
            .resolution = @intCast(i),
        };
        const serialized = try serialization.serialize(cell);
        const expected = try std.fmt.parseInt(u64, mask, 2);
        try std.testing.expectEqual(expected, serialized);
    }
}

test "serialization.correctly_extracts_resolution" {
    for (RESOLUTION_MASKS, 0..) |binary, i| {
        try std.testing.expectEqual(@as(usize, 64), binary.len);
        const n = try std.fmt.parseInt(u64, binary, 2);
        const resolution = serialization.get_resolution(n);
        try std.testing.expectEqual(@as(i32, @intCast(i)), resolution);
    }
}

test "serialization.encodes_origin_segment_and_s_correctly" {
    const origins = origin.get_origins();
    const origin0 = origins[0];

    const cell = A5Cell{
        .origin_id = origin0.id,
        .segment = 4,
        .s = 0,
        .resolution = serialization.MAX_RESOLUTION - 1,
    };
    const serialized = try serialization.serialize(cell);
    try std.testing.expectEqual(@as(u64, 0b10), serialized);
}

test "serialization.errors_when_s_is_too_large_for_resolution" {
    const origins = origin.get_origins();
    const origin0 = origins[0];

    const cell = A5Cell{
        .origin_id = origin0.id,
        .segment = 0,
        .s = 16,
        .resolution = 3,
    };
    try std.testing.expectError(serialization.SerializationError.STooLarge, serialization.serialize(cell));
}

test "serialization.errors_when_resolution_exceeds_maximum" {
    const origins = origin.get_origins();
    const origin0 = origins[0];

    const cell = A5Cell{
        .origin_id = origin0.id,
        .segment = 0,
        .s = 0,
        .resolution = 31,
    };
    try std.testing.expectError(serialization.SerializationError.ResolutionTooLarge, serialization.serialize(cell));
}

test "serialization.round_trip_resolution_masks" {
    var n: usize = 0;
    var i: usize = @intCast(serialization.FIRST_HILBERT_RESOLUTION);
    while (i < RESOLUTION_MASKS.len) : (i += 1) {
        if (5 * (n + 1) >= 60) {
            n += 1;
            continue;
        }

        const mask_value = try std.fmt.parseInt(u64, RESOLUTION_MASKS[i], 2);
        const combined = (@as(u64, @intCast(5 * (n + 1))) << 58) | (mask_value & serialization.REMOVAL_MASK);
        const deserialized = try serialization.deserialize(combined);
        const reserialized = try serialization.serialize(deserialized);
        try std.testing.expectEqual(combined, reserialized);
        n += 1;
    }
}

test "serialization.round_trip_test_ids" {
    var parsed = try load_test_ids();
    defer parsed.deinit();

    for (parsed.value) |id| {
        const serialized = try std.fmt.parseInt(u64, id, 16);
        const deserialized = try serialization.deserialize(serialized);
        const reserialized = try serialization.serialize(deserialized);
        try std.testing.expectEqual(serialized, reserialized);
    }
}

test "serialization.round_trip_between_cell_to_parent_and_cell_to_children" {
    var parsed = try load_test_ids();
    defer parsed.deinit();

    for (parsed.value) |id| {
        const cell = try std.fmt.parseInt(u64, id, 16);
        const children = try serialization.cell_to_children(std.testing.allocator, cell, null);
        defer std.testing.allocator.free(children);

        if (children.len > 0) {
            const child = children[0];
            const parent = try serialization.cell_to_parent(child, null);
            try std.testing.expectEqual(cell, parent);

            for (children) |c| {
                const p = try serialization.cell_to_parent(c, null);
                try std.testing.expectEqual(cell, p);
            }
        }
    }
}

test "serialization.cell_to_children_with_same_resolution_returns_original_cell" {
    var parsed = try load_test_ids();
    defer parsed.deinit();

    for (parsed.value) |id| {
        const cell = try std.fmt.parseInt(u64, id, 16);
        const current_resolution = serialization.get_resolution(cell);
        const children = try serialization.cell_to_children(std.testing.allocator, cell, current_resolution);
        defer std.testing.allocator.free(children);

        try std.testing.expectEqual(@as(usize, 1), children.len);
        try std.testing.expectEqual(cell, children[0]);
    }
}

test "serialization.cell_to_parent_with_same_resolution_returns_original_cell" {
    var parsed = try load_test_ids();
    defer parsed.deinit();

    for (parsed.value) |id| {
        const cell = try std.fmt.parseInt(u64, id, 16);
        const current_resolution = serialization.get_resolution(cell);
        const parent = try serialization.cell_to_parent(cell, current_resolution);
        try std.testing.expectEqual(cell, parent);
    }
}

test "serialization.non_hilbert_to_non_hilbert_hierarchy" {
    const origins = origin.get_origins();
    const origin0 = origins[0];

    const cell_data = A5Cell{
        .origin_id = origin0.id,
        .segment = 0,
        .s = 0,
        .resolution = 0,
    };
    const cell = try serialization.serialize(cell_data);
    const children = try serialization.cell_to_children(std.testing.allocator, cell, null);
    defer std.testing.allocator.free(children);
    try std.testing.expectEqual(@as(usize, 5), children.len);

    for (children) |child| {
        const parent = try serialization.cell_to_parent(child, null);
        try std.testing.expectEqual(cell, parent);
    }
}

test "serialization.non_hilbert_to_hilbert_hierarchy" {
    const origins = origin.get_origins();
    const origin0 = origins[0];

    const cell_data = A5Cell{
        .origin_id = origin0.id,
        .segment = 0,
        .s = 0,
        .resolution = 1,
    };
    const cell = try serialization.serialize(cell_data);
    const children = try serialization.cell_to_children(std.testing.allocator, cell, null);
    defer std.testing.allocator.free(children);
    try std.testing.expectEqual(@as(usize, 4), children.len);

    for (children) |child| {
        const parent = try serialization.cell_to_parent(child, null);
        try std.testing.expectEqual(cell, parent);
    }
}

test "serialization.hilbert_to_non_hilbert_hierarchy" {
    const origins = origin.get_origins();
    const origin0 = origins[0];

    const cell_data = A5Cell{
        .origin_id = origin0.id,
        .segment = 0,
        .s = 0,
        .resolution = 2,
    };
    const cell = try serialization.serialize(cell_data);
    const parent = try serialization.cell_to_parent(cell, 1);
    const children = try serialization.cell_to_children(std.testing.allocator, parent, null);
    defer std.testing.allocator.free(children);

    try std.testing.expectEqual(@as(usize, 4), children.len);
    try std.testing.expect(std.mem.indexOfScalar(u64, children, cell) != null);
}

test "serialization.low_resolution_hierarchy_chain" {
    const origins = origin.get_origins();
    const origin0 = origins[0];
    const resolutions = [_]i32{ 0, 1, 2, 3, 4 };

    var cells = [_]u64{0} ** resolutions.len;
    for (resolutions, 0..) |res, i| {
        cells[i] = try serialization.serialize(.{
            .origin_id = origin0.id,
            .segment = 0,
            .s = 0,
            .resolution = res,
        });
    }

    var i: usize = 1;
    while (i < cells.len) : (i += 1) {
        const parent = try serialization.cell_to_parent(cells[i], null);
        try std.testing.expectEqual(cells[i - 1], parent);
    }

    i = 0;
    while (i + 1 < cells.len) : (i += 1) {
        const children = try serialization.cell_to_children(std.testing.allocator, cells[i], null);
        defer std.testing.allocator.free(children);
        try std.testing.expect(std.mem.indexOfScalar(u64, children, cells[i + 1]) != null);
    }
}

test "serialization.base_cell_division_counts" {
    const origins = origin.get_origins();
    const origin0 = origins[0];

    const base_cell = try serialization.serialize(.{
        .origin_id = origin0.id,
        .segment = 0,
        .s = 0,
        .resolution = -1,
    });

    var current_cells = try std.testing.allocator.alloc(u64, 1);
    current_cells[0] = base_cell;
    defer std.testing.allocator.free(current_cells);

    const expected_counts = [_]usize{ 12, 60, 240, 960 };
    for (expected_counts[0..3]) |expected_count| {
        var all_children = try std.ArrayList(u64).initCapacity(std.testing.allocator, 0);
        defer all_children.deinit(std.testing.allocator);

        for (current_cells) |cell| {
            const children = try serialization.cell_to_children(std.testing.allocator, cell, null);
            defer std.testing.allocator.free(children);
            try all_children.appendSlice(std.testing.allocator, children);
        }

        try std.testing.expectEqual(expected_count, all_children.items.len);
        std.testing.allocator.free(current_cells);
        current_cells = try all_children.toOwnedSlice(std.testing.allocator);
    }
}

test "serialization.get_res0_cells" {
    const res0_cells = try serialization.get_res0_cells(std.testing.allocator);
    defer std.testing.allocator.free(res0_cells);

    try std.testing.expectEqual(@as(usize, 12), res0_cells.len);
    for (res0_cells) |cell| {
        try std.testing.expectEqual(@as(i32, 0), serialization.get_resolution(cell));
    }
}
