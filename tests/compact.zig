const std = @import("std");
const a5 = @import("a5");
const support = @import("a5_test_support");
const fixtures = support.fixtures;

const compact_mod = a5.core.compact;
const hex = a5.core.hex;
const serialization = a5.core.serialization;

const CompactTestCase = struct {
    name: []const u8,
    description: []const u8,
    input: []const []const u8,
    @"expectedOutput": []const []const u8,
};

const UncompactTestCase = struct {
    name: []const u8,
    description: []const u8,
    input: []const []const u8,
    @"targetResolution": i32,
    @"expectedCount": ?usize = null,
    @"expectedError": ?bool = null,
};

const RoundTripTestCase = struct {
    name: []const u8,
    description: []const u8,
    @"initialCells": []const []const u8,
    @"afterCompact": []const []const u8,
    @"targetResolution": i32,
    @"expectedCount": ?usize = null,
    @"expectedFinalCount": ?usize = null,
};

const CompactFixtures = struct {
    compact: []const CompactTestCase,
    uncompact: []const UncompactTestCase,
    @"roundTrip": []const RoundTripTestCase,
};

fn sort_u64(values: []u64) void {
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

fn parse_hex_list(allocator: std.mem.Allocator, ids: []const []const u8) ![]u64 {
    var out = try allocator.alloc(u64, ids.len);
    for (ids, 0..) |id, i| {
        out[i] = try hex.hex_to_u64(id);
    }
    return out;
}

fn load_compact_fixtures() !std.json.Parsed(CompactFixtures) {
    return fixtures.parseFixture(CompactFixtures, "compact.json", std.testing.allocator);
}

test "compact fixtures: uncompact happy path cases" {
    var parsed = try load_compact_fixtures();
    defer parsed.deinit();

    for (parsed.value.uncompact) |test_case| {
        if (test_case.@"expectedError" orelse false) {
            continue;
        }

        const input_cells = try parse_hex_list(std.testing.allocator, test_case.input);
        defer std.testing.allocator.free(input_cells);

        const result = try compact_mod.uncompact(std.testing.allocator, input_cells, test_case.@"targetResolution");
        defer std.testing.allocator.free(result);

        if (test_case.@"expectedCount") |expected_count| {
            try std.testing.expectEqual(expected_count, result.len);
        }

        for (result) |cell_id| {
            const cell_data = try serialization.deserialize(cell_id);
            try std.testing.expectEqual(test_case.@"targetResolution", cell_data.resolution);
        }
    }
}

test "compact fixtures: uncompact lower resolution returns error" {
    var parsed = try load_compact_fixtures();
    defer parsed.deinit();

    var found_error_case = false;
    for (parsed.value.uncompact) |test_case| {
        if (!(test_case.@"expectedError" orelse false)) continue;

        const input_cells = try parse_hex_list(std.testing.allocator, test_case.input);
        defer std.testing.allocator.free(input_cells);

        try std.testing.expectError(
            compact_mod.Error.TargetResolutionTooLow,
            compact_mod.uncompact(std.testing.allocator, input_cells, test_case.@"targetResolution"),
        );
        found_error_case = true;
        break;
    }

    try std.testing.expect(found_error_case);
}

test "compact fixtures: compact cases" {
    var parsed = try load_compact_fixtures();
    defer parsed.deinit();

    for (parsed.value.compact) |test_case| {
        const input_cells = try parse_hex_list(std.testing.allocator, test_case.input);
        defer std.testing.allocator.free(input_cells);

        const expected = try parse_hex_list(std.testing.allocator, test_case.@"expectedOutput");
        defer std.testing.allocator.free(expected);
        sort_u64(expected);

        const result = try compact_mod.compact(std.testing.allocator, input_cells);
        defer std.testing.allocator.free(result);
        sort_u64(result);

        try std.testing.expectEqual(expected.len, result.len);
        for (expected, result) |expected_cell, actual_cell| {
            try std.testing.expectEqual(expected_cell, actual_cell);
        }
    }
}

test "compact fixtures: round trip cases" {
    var parsed = try load_compact_fixtures();
    defer parsed.deinit();

    for (parsed.value.@"roundTrip") |test_case| {
        const initial_cells = try parse_hex_list(std.testing.allocator, test_case.@"initialCells");
        defer std.testing.allocator.free(initial_cells);

        const expected_after_compact = try parse_hex_list(std.testing.allocator, test_case.@"afterCompact");
        defer std.testing.allocator.free(expected_after_compact);
        sort_u64(expected_after_compact);

        const compact_result = try compact_mod.compact(std.testing.allocator, initial_cells);
        defer std.testing.allocator.free(compact_result);
        sort_u64(compact_result);

        try std.testing.expectEqual(expected_after_compact.len, compact_result.len);
        for (expected_after_compact, compact_result) |expected_cell, actual_cell| {
            try std.testing.expectEqual(expected_cell, actual_cell);
        }

        const uncompact_result = try compact_mod.uncompact(
            std.testing.allocator,
            expected_after_compact,
            test_case.@"targetResolution",
        );
        defer std.testing.allocator.free(uncompact_result);

        if (test_case.@"expectedCount") |expected_count| {
            try std.testing.expectEqual(expected_count, uncompact_result.len);
        }
        if (test_case.@"expectedFinalCount") |expected_final_count| {
            try std.testing.expectEqual(expected_final_count, uncompact_result.len);
        }

        for (uncompact_result) |cell_id| {
            const cell_data = try serialization.deserialize(cell_id);
            try std.testing.expectEqual(test_case.@"targetResolution", cell_data.resolution);
        }
    }
}
