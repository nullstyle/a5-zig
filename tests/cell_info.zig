const std = @import("std");
const support = @import("a5_test_support");
const a5 = @import("a5");

const cell_info = a5.core.cell_info;
const fixtures = support.fixtures;

const NumCellsFixture = struct {
    resolution: i32,
    count: u64,
};

const CellAreaFixture = struct {
    resolution: i32,
    @"areaM2": f64,
};

const CellInfoFixtures = struct {
    numCells: []const NumCellsFixture,
    cellArea: []const CellAreaFixture,
};

fn load_cell_info_fixtures() !std.json.Parsed(CellInfoFixtures) {
    return fixtures.parseFixture(CellInfoFixtures, "cell-info.json", std.testing.allocator);
}

test "cell_info.get_num_cells" {
    var parsed = try load_cell_info_fixtures();
    defer parsed.deinit();

    for (parsed.value.numCells) |fixture| {
        try std.testing.expectEqual(fixture.count, cell_info.get_num_cells(fixture.resolution));
    }
}

test "cell_info.cell_area" {
    var parsed = try load_cell_info_fixtures();
    defer parsed.deinit();

    for (parsed.value.cellArea) |fixture| {
        try std.testing.expectEqual(fixture.@"areaM2", cell_info.cell_area(fixture.resolution));
    }
}
