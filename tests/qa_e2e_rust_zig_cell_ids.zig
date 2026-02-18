const std = @import("std");
const a5 = @import("a5");

const serialization = a5.core.serialization;
const cell_info = a5.core.cell_info;
const LonLat = a5.coordinate_systems.LonLat;

const MAX_RESOLUTION_TO_COMPARE: i32 = 9;
const MAX_COMMAND_OUTPUT_BYTES: usize = 512 * 1024 * 1024;
const MAX_POLYGON_SAMPLES_PER_RESOLUTION: usize = 32;
const POLYGON_TOLERANCE_RADIANS: f64 = 5e-5;
const DEEP_RANDOM_PARITY_RESOLUTION: i32 = 25;
const DEEP_RANDOM_PARITY_BATCH_SIZE: usize = 32;
const DEEP_RANDOM_PARITY_DURATION_NS: i128 = 10 * std.time.ns_per_s;
const DEEP_RANDOM_PARITY_SEED: u64 = 0x00d3_3e5e_0a4c_1e25;
const DEEP_RANDOM_POINT_MIN_T: f64 = 0.000001;
const DEEP_RANDOM_POINT_MAX_T: f64 = 0.000005;
const DEEP_RANDOM_POINT_CONTAINMENT_EPSILON: f64 = 1e-8;

const CommandOutput = struct {
    stdout: []const u8,
    stderr: []const u8,
};

const CommandError = error{CommandFailed};
const ParseError = error{InvalidBoundaryOutput};
const BoundaryCompareError = error{BoundaryMismatch};

const BoundaryPoint = struct {
    lon: f64,
    lat: f64,
};

const RustBoundary = struct {
    id: u64,
    points: []BoundaryPoint,
};

const NearestPoint = struct {
    index: usize,
    distance_radians: f64,
};

const PointMismatch = struct {
    point_index: usize,
    nearest_index: usize,
    distance_radians: f64,
};

fn randomCellAtResolution(
    random: std.Random,
    resolution: i32,
) !u64 {
    if (resolution < 0 or resolution > serialization.MAX_RESOLUTION) {
        return error.InvalidResolution;
    }

    const origin_id: u8 = @intCast(random.uintLessThan(usize, 12));
    const segment: usize = if (resolution > 0) random.uintLessThan(usize, 5) else 0;
    var s: u64 = 0;

    if (resolution >= serialization.FIRST_HILBERT_RESOLUTION) {
        const hilbert_levels = resolution - serialization.FIRST_HILBERT_RESOLUTION + 1;
        const hilbert_bits: u6 = @intCast(2 * hilbert_levels);
        const max_s: u64 = @as(u64, 1) << hilbert_bits;
        s = random.uintLessThan(u64, max_s);
    }

    return serialization.serialize(.{
        .origin_id = origin_id,
        .segment = segment,
        .s = s,
        .resolution = resolution,
    });
}

fn runCommand(
    allocator: std.mem.Allocator,
    argv: []const []const u8,
    cwd: ?[]const u8,
) !CommandOutput {
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv,
        .cwd = cwd,
        .max_output_bytes = MAX_COMMAND_OUTPUT_BYTES,
    });

    switch (result.term) {
        .Exited => |code| {
            if (code != 0) {
                if (result.stderr.len > 0) std.debug.print("Command stderr:\n{s}\n", .{result.stderr});
                if (result.stdout.len > 0) std.debug.print("Command stdout:\n{s}\n", .{result.stdout});
                allocator.free(result.stdout);
                allocator.free(result.stderr);
                return CommandError.CommandFailed;
            }
        },
        else => {
            if (result.stderr.len > 0) std.debug.print("Command stderr:\n{s}\n", .{result.stderr});
            if (result.stdout.len > 0) std.debug.print("Command stdout:\n{s}\n", .{result.stdout});
            allocator.free(result.stdout);
            allocator.free(result.stderr);
            return CommandError.CommandFailed;
        },
    }

    return .{
        .stdout = result.stdout,
        .stderr = result.stderr,
    };
}

fn runRustExportCellIds(allocator: std.mem.Allocator, resolution: i32) !CommandOutput {
    var resolution_buffer: [16]u8 = undefined;
    const resolution_text = try std.fmt.bufPrint(&resolution_buffer, "{d}", .{resolution});
    const argv = [_][]const u8{
        "cargo",
        "run",
        "--quiet",
        "--manifest-path",
        "tests/qa_rust_oracle/Cargo.toml",
        "--target-dir",
        ".zig-cache/qa_rust_oracle_target",
        "--",
        "cell-ids",
        resolution_text,
    };
    return runCommand(allocator, &argv, null);
}

fn runRustExportCellBoundaries(
    allocator: std.mem.Allocator,
    cell_ids: []const u64,
) !CommandOutput {
    var argv = try std.ArrayList([]const u8).initCapacity(allocator, 10 + cell_ids.len);
    defer argv.deinit(allocator);

    var encoded_ids = try std.ArrayList([]u8).initCapacity(allocator, cell_ids.len);
    defer {
        for (encoded_ids.items) |encoded| allocator.free(encoded);
        encoded_ids.deinit(allocator);
    }

    try argv.appendSlice(allocator, &.{
        "cargo",
        "run",
        "--quiet",
        "--manifest-path",
        "tests/qa_rust_oracle/Cargo.toml",
        "--target-dir",
        ".zig-cache/qa_rust_oracle_target",
        "--",
        "cell-boundaries",
    });

    for (cell_ids) |cell_id| {
        const encoded = try std.fmt.allocPrint(allocator, "{x}", .{cell_id});
        try encoded_ids.append(allocator, encoded);
        try argv.append(allocator, encoded);
    }

    return runCommand(allocator, argv.items, null);
}

fn runRustLonlatToCell(
    allocator: std.mem.Allocator,
    resolution: i32,
    points: []const LonLat,
) !CommandOutput {
    var argv = try std.ArrayList([]const u8).initCapacity(allocator, 11 + points.len);
    defer argv.deinit(allocator);

    var encoded_points = try std.ArrayList([]u8).initCapacity(allocator, points.len);
    defer {
        for (encoded_points.items) |encoded| allocator.free(encoded);
        encoded_points.deinit(allocator);
    }

    var resolution_buffer: [16]u8 = undefined;
    const resolution_text = try std.fmt.bufPrint(&resolution_buffer, "{d}", .{resolution});

    try argv.appendSlice(allocator, &.{
        "cargo",
        "run",
        "--quiet",
        "--manifest-path",
        "tests/qa_rust_oracle/Cargo.toml",
        "--target-dir",
        ".zig-cache/qa_rust_oracle_target",
        "--",
        "lonlat-to-cell",
        resolution_text,
    });

    for (points) |point| {
        const encoded = try std.fmt.allocPrint(
            allocator,
            "{d:.17},{d:.17}",
            .{ point.longitude(), point.latitude() },
        );
        try encoded_points.append(allocator, encoded);
        try argv.append(allocator, encoded);
    }

    return runCommand(allocator, argv.items, null);
}

fn parseHexCells(allocator: std.mem.Allocator, stdout: []const u8) ![]u64 {
    var ids = try std.ArrayList(u64).initCapacity(allocator, 0);
    errdefer ids.deinit(allocator);

    var lines = std.mem.splitSequence(u8, stdout, "\n");
    while (lines.next()) |line_raw| {
        const line = std.mem.trim(u8, line_raw, " \t\r\n");
        if (line.len == 0) continue;
        try ids.append(allocator, try std.fmt.parseInt(u64, line, 16));
    }

    return ids.toOwnedSlice(allocator);
}

fn parseRustBoundaries(
    allocator: std.mem.Allocator,
    stdout: []const u8,
) ![]RustBoundary {
    var boundaries = try std.ArrayList(RustBoundary).initCapacity(allocator, 0);
    errdefer {
        for (boundaries.items) |boundary| allocator.free(boundary.points);
        boundaries.deinit(allocator);
    }

    var lines = std.mem.splitSequence(u8, stdout, "\n");
    while (lines.next()) |line_raw| {
        const line = std.mem.trim(u8, line_raw, " \t\r\n");
        if (line.len == 0) continue;

        var fields = std.mem.splitSequence(u8, line, "\t");
        const id_text = fields.next() orelse return ParseError.InvalidBoundaryOutput;
        const points_text = fields.next() orelse return ParseError.InvalidBoundaryOutput;
        if (fields.next() != null) return ParseError.InvalidBoundaryOutput;

        const id = try std.fmt.parseInt(u64, id_text, 16);

        var points = try std.ArrayList(BoundaryPoint).initCapacity(allocator, 0);
        errdefer points.deinit(allocator);

        var point_tokens = std.mem.splitSequence(u8, points_text, ";");
        while (point_tokens.next()) |point_raw| {
            const point_text = std.mem.trim(u8, point_raw, " \t\r\n");
            if (point_text.len == 0) continue;

            var coords = std.mem.splitSequence(u8, point_text, ",");
            const lon_text = coords.next() orelse return ParseError.InvalidBoundaryOutput;
            const lat_text = coords.next() orelse return ParseError.InvalidBoundaryOutput;
            if (coords.next() != null) return ParseError.InvalidBoundaryOutput;

            const lon = try std.fmt.parseFloat(f64, lon_text);
            const lat = try std.fmt.parseFloat(f64, lat_text);
            try points.append(allocator, .{ .lon = lon, .lat = lat });
        }

        try boundaries.append(allocator, .{
            .id = id,
            .points = try points.toOwnedSlice(allocator),
        });
    }

    return boundaries.toOwnedSlice(allocator);
}

fn freeRustBoundaries(allocator: std.mem.Allocator, boundaries: []RustBoundary) void {
    for (boundaries) |boundary| allocator.free(boundary.points);
    allocator.free(boundaries);
}

fn buildPolygonSampleIds(
    allocator: std.mem.Allocator,
    cell_ids: []const u64,
) ![]u64 {
    const sample_count = @min(MAX_POLYGON_SAMPLES_PER_RESOLUTION, cell_ids.len);
    const sample = try allocator.alloc(u64, sample_count);
    if (sample_count == 0) return sample;
    if (sample_count == 1) {
        sample[0] = cell_ids[0];
        return sample;
    }

    var i: usize = 0;
    while (i < sample_count) : (i += 1) {
        const numerator = @as(u128, i) * @as(u128, cell_ids.len - 1);
        const denominator = @as(u128, sample_count - 1);
        const index: usize = @intCast(numerator / denominator);
        sample[i] = cell_ids[index];
    }

    return sample;
}

fn wrappedLongitudeDelta(a: f64, b: f64) f64 {
    const raw = a - b;
    const shifted = raw + 180.0;
    const normalized = shifted - std.math.floor(shifted / 360.0) * 360.0;
    return normalized - 180.0;
}

const UnitVec3 = struct {
    x: f64,
    y: f64,
    z: f64,
};

fn lonLatToUnitVector(lon_degrees: f64, lat_degrees: f64) UnitVec3 {
    const lon = lon_degrees * std.math.pi / 180.0;
    const lat = lat_degrees * std.math.pi / 180.0;
    const cos_lat = std.math.cos(lat);
    return .{
        .x = cos_lat * std.math.cos(lon),
        .y = cos_lat * std.math.sin(lon),
        .z = std.math.sin(lat),
    };
}

fn normalizeUnitVector(vec: UnitVec3) UnitVec3 {
    const len = std.math.sqrt(vec.x * vec.x + vec.y * vec.y + vec.z * vec.z);
    if (len == 0.0) {
        return .{ .x = 1.0, .y = 0.0, .z = 0.0 };
    }
    return .{
        .x = vec.x / len,
        .y = vec.y / len,
        .z = vec.z / len,
    };
}

fn unitVectorToLonLat(vec: UnitVec3) LonLat {
    const normalized = normalizeUnitVector(vec);
    const lon_radians = std.math.atan2(normalized.y, normalized.x);
    const lat_radians = std.math.atan2(
        normalized.z,
        std.math.sqrt(normalized.x * normalized.x + normalized.y * normalized.y),
    );
    const radians_to_degrees = 180.0 / std.math.pi;
    return LonLat.new(
        lon_radians * radians_to_degrees,
        lat_radians * radians_to_degrees,
    );
}

fn pointTowardBoundary(center: LonLat, boundary_point: LonLat, t: f64) LonLat {
    const center_vec = lonLatToUnitVector(center.longitude(), center.latitude());
    const boundary_vec = lonLatToUnitVector(boundary_point.longitude(), boundary_point.latitude());
    const blended = UnitVec3{
        .x = center_vec.x * (1.0 - t) + boundary_vec.x * t,
        .y = center_vec.y * (1.0 - t) + boundary_vec.y * t,
        .z = center_vec.z * (1.0 - t) + boundary_vec.z * t,
    };
    return unitVectorToLonLat(blended);
}

fn randomInteriorPointForCell(
    random: std.Random,
    cell_id: u64,
    boundary: []const LonLat,
) !LonLat {
    const center = try a5.cell_to_lonlat(cell_id);
    const boundary_len = effectiveZigBoundaryLen(boundary);
    if (boundary_len == 0) return center;

    const cell_data = try serialization.deserialize(cell_id);
    const boundary_index = random.uintLessThan(usize, boundary_len);
    const target = boundary[boundary_index];
    var t = DEEP_RANDOM_POINT_MIN_T +
        (DEEP_RANDOM_POINT_MAX_T - DEEP_RANDOM_POINT_MIN_T) * random.float(f64);

    var attempt: usize = 0;
    while (attempt < 10) : (attempt += 1) {
        const candidate = pointTowardBoundary(center, target, t);
        const distance = try a5.core.cell.a5cell_contains_point(cell_data, candidate);
        if (distance > DEEP_RANDOM_POINT_CONTAINMENT_EPSILON) return candidate;
        t *= 0.5;
    }

    return center;
}

fn angularDistanceRadians(a: UnitVec3, b: UnitVec3) f64 {
    const dot = std.math.clamp(a.x * b.x + a.y * b.y + a.z * b.z, -1.0, 1.0);
    return std.math.acos(dot);
}

fn pointsClose(
    zig_point: LonLat,
    rust_point: BoundaryPoint,
) bool {
    const zig_vec = lonLatToUnitVector(zig_point.longitude(), zig_point.latitude());
    const rust_vec = lonLatToUnitVector(rust_point.lon, rust_point.lat);
    return angularDistanceRadians(zig_vec, rust_vec) <= POLYGON_TOLERANCE_RADIANS;
}

fn boundaryPointsClose(a: BoundaryPoint, b: BoundaryPoint) bool {
    const a_vec = lonLatToUnitVector(a.lon, a.lat);
    const b_vec = lonLatToUnitVector(b.lon, b.lat);
    return angularDistanceRadians(a_vec, b_vec) <= POLYGON_TOLERANCE_RADIANS;
}

fn pointAngularDistanceRadians(zig_point: LonLat, rust_point: BoundaryPoint) f64 {
    const zig_vec = lonLatToUnitVector(zig_point.longitude(), zig_point.latitude());
    const rust_vec = lonLatToUnitVector(rust_point.lon, rust_point.lat);
    return angularDistanceRadians(zig_vec, rust_vec);
}

fn nearestRustPointForZig(
    zig_point: LonLat,
    rust_boundary: []const BoundaryPoint,
    rust_len: usize,
) NearestPoint {
    var nearest_index: usize = 0;
    var nearest_distance = std.math.inf(f64);
    var i: usize = 0;
    while (i < rust_len) : (i += 1) {
        const distance = pointAngularDistanceRadians(zig_point, rust_boundary[i]);
        if (distance < nearest_distance) {
            nearest_distance = distance;
            nearest_index = i;
        }
    }
    return .{ .index = nearest_index, .distance_radians = nearest_distance };
}

fn nearestZigPointForRust(
    rust_point: BoundaryPoint,
    zig_boundary: []const LonLat,
    zig_len: usize,
) NearestPoint {
    var nearest_index: usize = 0;
    var nearest_distance = std.math.inf(f64);
    var i: usize = 0;
    while (i < zig_len) : (i += 1) {
        const distance = pointAngularDistanceRadians(zig_boundary[i], rust_point);
        if (distance < nearest_distance) {
            nearest_distance = distance;
            nearest_index = i;
        }
    }
    return .{ .index = nearest_index, .distance_radians = nearest_distance };
}

fn printBoundarySamplePoints(
    zig_boundary: []const LonLat,
    rust_boundary: []const BoundaryPoint,
    zig_len: usize,
    rust_len: usize,
) void {
    const sample_count = @min(@as(usize, 3), @min(zig_len, rust_len));
    if (sample_count == 0) return;

    std.debug.print("  sample points (index: zig_lon,zig_lat | rust_lon,rust_lat):\n", .{});
    var i: usize = 0;
    while (i < sample_count) : (i += 1) {
        std.debug.print(
            "    {d}: {d:.9},{d:.9} | {d:.9},{d:.9}\n",
            .{
                i,
                zig_boundary[i].longitude(),
                zig_boundary[i].latitude(),
                rust_boundary[i].lon,
                rust_boundary[i].lat,
            },
        );
    }
}

fn effectiveZigBoundaryLen(boundary: []const LonLat) usize {
    if (boundary.len > 1 and pointsClose(boundary[0], .{
        .lon = boundary[boundary.len - 1].longitude(),
        .lat = boundary[boundary.len - 1].latitude(),
    })) {
        return boundary.len - 1;
    }
    return boundary.len;
}

fn effectiveRustBoundaryLen(boundary: []const BoundaryPoint) usize {
    if (boundary.len > 1 and boundaryPointsClose(boundary[0], boundary[boundary.len - 1])) {
        return boundary.len - 1;
    }
    return boundary.len;
}

fn matchBoundaryWithOffset(
    zig_boundary: []const LonLat,
    rust_boundary: []const BoundaryPoint,
    len: usize,
    rust_start: usize,
    reverse: bool,
) bool {
    var i: usize = 0;
    while (i < len) : (i += 1) {
        const rust_index = if (reverse)
            (rust_start + len - i) % len
        else
            (rust_start + i) % len;
        if (!pointsClose(zig_boundary[i], rust_boundary[rust_index])) return false;
    }
    return true;
}

fn boundaryHasPointCloseToRust(
    zig_boundary: []const LonLat,
    zig_len: usize,
    rust_point: BoundaryPoint,
) bool {
    var i: usize = 0;
    while (i < zig_len) : (i += 1) {
        if (pointsClose(zig_boundary[i], rust_point)) return true;
    }
    return false;
}

fn boundaryHasPointCloseToZig(
    rust_boundary: []const BoundaryPoint,
    rust_len: usize,
    zig_point: LonLat,
) bool {
    var i: usize = 0;
    while (i < rust_len) : (i += 1) {
        if (pointsClose(zig_point, rust_boundary[i])) return true;
    }
    return false;
}

fn expectSameBoundary(
    resolution: i32,
    cell_id: u64,
    zig_boundary: []const LonLat,
    rust_boundary: []const BoundaryPoint,
) !void {
    const zig_len = effectiveZigBoundaryLen(zig_boundary);
    const rust_len = effectiveRustBoundaryLen(rust_boundary);
    if (zig_len != rust_len) {
        std.debug.print(
            "Boundary mismatch: resolution={d} cell={x:0>16} length zig={d} rust={d}\n",
            .{ resolution, cell_id, zig_len, rust_len },
        );
        return BoundaryCompareError.BoundaryMismatch;
    }
    if (zig_len == 0) return;

    var rust_start: usize = 0;
    var matched = false;
    while (rust_start < rust_len) : (rust_start += 1) {
        if (!pointsClose(zig_boundary[0], rust_boundary[rust_start])) continue;
        if (matchBoundaryWithOffset(zig_boundary, rust_boundary, zig_len, rust_start, false)) {
            matched = true;
            break;
        }
        if (matchBoundaryWithOffset(zig_boundary, rust_boundary, zig_len, rust_start, true)) {
            matched = true;
            break;
        }
    }
    if (matched) return;

    var i: usize = 0;
    var zig_fail_count: usize = 0;
    var rust_fail_count: usize = 0;
    var worst_zig_mismatch = PointMismatch{
        .point_index = 0,
        .nearest_index = 0,
        .distance_radians = 0.0,
    };
    var worst_rust_mismatch = PointMismatch{
        .point_index = 0,
        .nearest_index = 0,
        .distance_radians = 0.0,
    };
    var first_zig_failure: ?PointMismatch = null;
    var first_rust_failure: ?PointMismatch = null;

    while (i < zig_len) : (i += 1) {
        if (!boundaryHasPointCloseToZig(rust_boundary, rust_len, zig_boundary[i])) {
            zig_fail_count += 1;
            const nearest = nearestRustPointForZig(zig_boundary[i], rust_boundary, rust_len);
            const mismatch = PointMismatch{
                .point_index = i,
                .nearest_index = nearest.index,
                .distance_radians = nearest.distance_radians,
            };
            if (first_zig_failure == null) first_zig_failure = mismatch;
            if (mismatch.distance_radians > worst_zig_mismatch.distance_radians) {
                worst_zig_mismatch = mismatch;
            }
        }
    }
    i = 0;
    while (i < rust_len) : (i += 1) {
        if (!boundaryHasPointCloseToRust(zig_boundary, zig_len, rust_boundary[i])) {
            rust_fail_count += 1;
            const nearest = nearestZigPointForRust(rust_boundary[i], zig_boundary, zig_len);
            const mismatch = PointMismatch{
                .point_index = i,
                .nearest_index = nearest.index,
                .distance_radians = nearest.distance_radians,
            };
            if (first_rust_failure == null) first_rust_failure = mismatch;
            if (mismatch.distance_radians > worst_rust_mismatch.distance_radians) {
                worst_rust_mismatch = mismatch;
            }
        }
    }

    const rad_to_deg = 180.0 / std.math.pi;
    std.debug.print(
        "Boundary mismatch: resolution={d} cell={x:0>16}\n",
        .{ resolution, cell_id },
    );
    std.debug.print(
        "  tolerance={d:.9} rad ({d:.9} deg)\n",
        .{ POLYGON_TOLERANCE_RADIANS, POLYGON_TOLERANCE_RADIANS * rad_to_deg },
    );
    std.debug.print(
        "  sizes: zig={d} rust={d}\n",
        .{ zig_len, rust_len },
    );
    std.debug.print(
        "  unmatched points: zig->rust={d} rust->zig={d}\n",
        .{ zig_fail_count, rust_fail_count },
    );

    if (first_zig_failure) |m| {
        std.debug.print(
            "  first zig miss: zig[{d}] nearest rust[{d}] distance={d:.9} rad ({d:.9} deg)\n",
            .{ m.point_index, m.nearest_index, m.distance_radians, m.distance_radians * rad_to_deg },
        );
    }
    if (first_rust_failure) |m| {
        std.debug.print(
            "  first rust miss: rust[{d}] nearest zig[{d}] distance={d:.9} rad ({d:.9} deg)\n",
            .{ m.point_index, m.nearest_index, m.distance_radians, m.distance_radians * rad_to_deg },
        );
    }
    std.debug.print(
        "  worst zig miss: zig[{d}] nearest rust[{d}] distance={d:.9} rad ({d:.9} deg)\n",
        .{
            worst_zig_mismatch.point_index,
            worst_zig_mismatch.nearest_index,
            worst_zig_mismatch.distance_radians,
            worst_zig_mismatch.distance_radians * rad_to_deg,
        },
    );
    std.debug.print(
        "  worst rust miss: rust[{d}] nearest zig[{d}] distance={d:.9} rad ({d:.9} deg)\n",
        .{
            worst_rust_mismatch.point_index,
            worst_rust_mismatch.nearest_index,
            worst_rust_mismatch.distance_radians,
            worst_rust_mismatch.distance_radians * rad_to_deg,
        },
    );
    if (worst_zig_mismatch.point_index < zig_len and worst_zig_mismatch.nearest_index < rust_len) {
        const zig_point = zig_boundary[worst_zig_mismatch.point_index];
        const rust_point = rust_boundary[worst_zig_mismatch.nearest_index];
        std.debug.print(
            "  worst zig point pair: zig=({d:.9},{d:.9}) rust=({d:.9},{d:.9})\n",
            .{
                zig_point.longitude(),
                zig_point.latitude(),
                rust_point.lon,
                rust_point.lat,
            },
        );
    }
    printBoundarySamplePoints(zig_boundary, rust_boundary, zig_len, rust_len);
    return BoundaryCompareError.BoundaryMismatch;
}

fn expectSameCellSet(
    zig_cells: []u64,
    rust_cells: []u64,
) !void {
    try std.testing.expectEqual(zig_cells.len, rust_cells.len);
    std.mem.sort(u64, zig_cells, {}, std.sort.asc(u64));
    std.mem.sort(u64, rust_cells, {}, std.sort.asc(u64));

    for (zig_cells, 0..) |zig_cell, i| {
        try std.testing.expectEqual(zig_cell, rust_cells[i]);
    }
}

test "qa e2e compare a5-rs and a5-zig cell outputs up to resolution 9" {
    var resolution: i32 = 0;
    while (resolution <= MAX_RESOLUTION_TO_COMPARE) : (resolution += 1) {
        const rust_output = try runRustExportCellIds(std.testing.allocator, resolution);
        defer std.testing.allocator.free(rust_output.stdout);
        defer std.testing.allocator.free(rust_output.stderr);

        const expected_count = cell_info.get_num_cells(resolution);
        const zig_cells = try serialization.cell_to_children(
            std.testing.allocator,
            serialization.WORLD_CELL,
            resolution,
        );
        defer std.testing.allocator.free(zig_cells);
        const rust_cells = try parseHexCells(std.testing.allocator, rust_output.stdout);
        defer std.testing.allocator.free(rust_cells);

        try std.testing.expectEqual(expected_count, @as(u64, zig_cells.len));
        try std.testing.expectEqual(expected_count, @as(u64, rust_cells.len));
        try expectSameCellSet(zig_cells, rust_cells);

        const polygon_sample_ids = try buildPolygonSampleIds(std.testing.allocator, rust_cells);
        defer std.testing.allocator.free(polygon_sample_ids);
        const rust_boundaries_output = try runRustExportCellBoundaries(std.testing.allocator, polygon_sample_ids);
        defer std.testing.allocator.free(rust_boundaries_output.stdout);
        defer std.testing.allocator.free(rust_boundaries_output.stderr);
        const rust_boundaries = try parseRustBoundaries(std.testing.allocator, rust_boundaries_output.stdout);
        defer freeRustBoundaries(std.testing.allocator, rust_boundaries);

        try std.testing.expectEqual(polygon_sample_ids.len, rust_boundaries.len);
        for (rust_boundaries, 0..) |rust_boundary, i| {
            try std.testing.expectEqual(polygon_sample_ids[i], rust_boundary.id);
            const zig_boundary = try a5.cell_to_boundary(std.testing.allocator, rust_boundary.id, .{
                .closed_ring = true,
                .segments = 1,
            });
            defer std.testing.allocator.free(zig_boundary);
            try expectSameBoundary(resolution, rust_boundary.id, zig_boundary, rust_boundary.points);
        }
    }
}

test "qa e2e deep random cell boundary parity against rust oracle (~10s)" {
    var prng = std.Random.DefaultPrng.init(DEEP_RANDOM_PARITY_SEED);
    const random = prng.random();

    const start_ns = std.time.nanoTimestamp();
    const deadline_ns = start_ns + DEEP_RANDOM_PARITY_DURATION_NS;

    var checked_cells: usize = 0;
    var batch_count: usize = 0;

    while (std.time.nanoTimestamp() < deadline_ns) : (batch_count += 1) {
        var batch = try std.ArrayList(u64).initCapacity(std.testing.allocator, DEEP_RANDOM_PARITY_BATCH_SIZE);
        defer batch.deinit(std.testing.allocator);

        var i: usize = 0;
        while (i < DEEP_RANDOM_PARITY_BATCH_SIZE) : (i += 1) {
            const cell_id = try randomCellAtResolution(random, DEEP_RANDOM_PARITY_RESOLUTION);
            try batch.append(std.testing.allocator, cell_id);
        }

        const rust_output = try runRustExportCellBoundaries(std.testing.allocator, batch.items);
        defer std.testing.allocator.free(rust_output.stdout);
        defer std.testing.allocator.free(rust_output.stderr);

        const rust_boundaries = try parseRustBoundaries(std.testing.allocator, rust_output.stdout);
        defer freeRustBoundaries(std.testing.allocator, rust_boundaries);

        var sampled_points = try std.ArrayList(LonLat).initCapacity(std.testing.allocator, rust_boundaries.len);
        defer sampled_points.deinit(std.testing.allocator);

        try std.testing.expectEqual(batch.items.len, rust_boundaries.len);
        for (rust_boundaries, 0..) |rust_boundary, idx| {
            try std.testing.expectEqual(batch.items[idx], rust_boundary.id);
            const zig_boundary = try a5.cell_to_boundary(std.testing.allocator, rust_boundary.id, .{
                .closed_ring = true,
                .segments = 1,
            });
            defer std.testing.allocator.free(zig_boundary);
            try expectSameBoundary(DEEP_RANDOM_PARITY_RESOLUTION, rust_boundary.id, zig_boundary, rust_boundary.points);
            const sampled_point = try randomInteriorPointForCell(random, rust_boundary.id, zig_boundary);
            try sampled_points.append(std.testing.allocator, sampled_point);
        }

        const rust_lonlat_output = try runRustLonlatToCell(
            std.testing.allocator,
            DEEP_RANDOM_PARITY_RESOLUTION,
            sampled_points.items,
        );
        defer std.testing.allocator.free(rust_lonlat_output.stdout);
        defer std.testing.allocator.free(rust_lonlat_output.stderr);

        const rust_lonlat_cells = try parseHexCells(std.testing.allocator, rust_lonlat_output.stdout);
        defer std.testing.allocator.free(rust_lonlat_cells);

        try std.testing.expectEqual(sampled_points.items.len, rust_lonlat_cells.len);
        for (sampled_points.items, 0..) |point, idx| {
            const zig_cell = try a5.lonlat_to_cell(point, DEEP_RANDOM_PARITY_RESOLUTION);
            const rust_cell = rust_lonlat_cells[idx];
            const source_cell = batch.items[idx];

            if (zig_cell != rust_cell) {
                std.debug.print(
                    "deep random lonlat parity mismatch: idx={d} lon={d:.12} lat={d:.12} source={x:0>16} zig={x:0>16} rust={x:0>16}\n",
                    .{
                        idx,
                        point.longitude(),
                        point.latitude(),
                        source_cell,
                        zig_cell,
                        rust_cell,
                    },
                );
            }

            try std.testing.expectEqual(source_cell, rust_cell);
            try std.testing.expectEqual(rust_cell, zig_cell);
        }

        checked_cells += batch.items.len;
    }

    try std.testing.expect(checked_cells > 0);
}
