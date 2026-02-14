const std = @import("std");
const coordinate_systems = @import("coordinate_systems");
const geometry = @import("geometry");
const constants = @import("constants.zig");
const ct = @import("coordinate_transforms.zig");
const hilbert = @import("hilbert.zig");
const core_origin = @import("origin.zig");
const serialization = @import("serialization.zig");
const tiling = @import("tiling.zig");
const core_utils = @import("utils.zig");
const dodecahedron = @import("cell_dodecahedron.zig");

const Face = coordinate_systems.Face;
const LonLat = coordinate_systems.LonLat;
const A5Cell = core_utils.A5Cell;
const PentagonShape = geometry.pentagon.PentagonShape;
const DodecahedronProjection = dodecahedron.DodecahedronProjection;

pub const Error = serialization.SerializationError || dodecahedron.DodecahedronProjection.Error || error{
    OutOfMemory,
    NoCandidateCell,
};

pub const CellToBoundaryOptions = struct {
    closed_ring: bool = true,
    segments: ?i32 = null,
};

pub fn lonlat_to_cell(lonlat: LonLat, resolution: i32) Error!u64 {
    if (resolution == -1) {
        return serialization.WORLD_CELL;
    }

    if (resolution < serialization.FIRST_HILBERT_RESOLUTION) {
        const estimate = try lonlat_to_estimate(lonlat, resolution);
        return serialization.serialize(estimate);
    }

    const sample_count: usize = 25;
    const total_samples = sample_count + 1;
    const hilbert_resolution = 1 + resolution - serialization.FIRST_HILBERT_RESOLUTION;
    const scale = 50.0 / std.math.pow(f64, 2.0, @as(f64, @floatFromInt(hilbert_resolution)));

    var samples: [total_samples]LonLat = undefined;
    samples[0] = lonlat;
    for (0..sample_count) |i| {
        const r = (@as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(sample_count))) * scale;
        samples[i + 1] = LonLat.new(
            lonlat.longitude() + std.math.cos(@as(f64, @floatFromInt(i))) * r,
            lonlat.latitude() + std.math.sin(@as(f64, @floatFromInt(i))) * r,
        );
    }

    var unique_keys: [total_samples]u64 = undefined;
    var unique_len: usize = 0;
    var best_cell: ?A5Cell = null;
    var best_distance: f64 = -std.math.inf(f64);

    for (samples) |sample| {
        const estimate = try lonlat_to_estimate(sample, resolution);
        const key = try serialization.serialize(estimate);

        var seen = false;
        for (unique_keys[0..unique_len]) |existing| {
            if (existing == key) {
                seen = true;
                break;
            }
        }
        if (seen) continue;

        unique_keys[unique_len] = key;
        unique_len += 1;

        const distance = try a5cell_contains_point(estimate, lonlat);
        if (distance > 0.0) {
            return key;
        }
        if (distance > best_distance) {
            best_distance = distance;
            best_cell = estimate;
        }
    }

    if (best_cell) |cell| {
        return serialization.serialize(cell);
    }
    return Error.NoCandidateCell;
}

fn lonlat_to_estimate(lonlat: LonLat, resolution: i32) Error!A5Cell {
    const spherical = ct.from_lon_lat(lonlat);
    const current_origin = core_origin.find_nearest_origin(spherical);

    const projection = try DodecahedronProjection.get_thread_local();
    var dodec_point = try projection.forward(spherical, current_origin.id);
    const polar = ct.to_polar(dodec_point);
    const quintant = tiling.get_quintant_polar(polar);
    const segment_orientation = core_origin.quintant_to_segment(quintant, current_origin);

    if (resolution < serialization.FIRST_HILBERT_RESOLUTION) {
        return A5Cell{
            .s = 0,
            .segment = segment_orientation.segment,
            .origin_id = current_origin.id,
            .resolution = resolution,
        };
    }

    if (quintant != 0) {
        const extra_angle = 2.0 * constants.PI_OVER_5.get() * @as(f64, @floatFromInt(quintant));
        const cos_angle = std.math.cos(-extra_angle);
        const sin_angle = std.math.sin(-extra_angle);
        dodec_point = Face.new(
            cos_angle * dodec_point.x() - sin_angle * dodec_point.y(),
            sin_angle * dodec_point.x() + cos_angle * dodec_point.y(),
        );
    }

    const hilbert_resolution = 1 + resolution - serialization.FIRST_HILBERT_RESOLUTION;
    const scale_factor = std.math.pow(f64, 2.0, @as(f64, @floatFromInt(hilbert_resolution)));
    dodec_point = Face.new(
        dodec_point.x() * scale_factor,
        dodec_point.y() * scale_factor,
    );

    const ij = ct.face_to_ij(dodec_point);
    const s = hilbert.ij_to_s(ij, @intCast(hilbert_resolution), segment_orientation.orientation);

    return A5Cell{
        .s = s,
        .segment = segment_orientation.segment,
        .origin_id = current_origin.id,
        .resolution = resolution,
    };
}

fn get_origin_for_cell(cell: A5Cell) core_utils.Origin {
    const origins = core_origin.get_origins();
    return origins[@as(usize, cell.origin_id)];
}

pub fn get_pentagon(cell: A5Cell) PentagonShape {
    const quintant_orientation = core_origin.segment_to_quintant(cell.segment, get_origin_for_cell(cell));

    if (cell.resolution == serialization.FIRST_HILBERT_RESOLUTION - 1) {
        return tiling.get_quintant_vertices(quintant_orientation.quintant);
    }
    if (cell.resolution == serialization.FIRST_HILBERT_RESOLUTION - 2) {
        return tiling.get_face_vertices();
    }

    const hilbert_resolution = cell.resolution - serialization.FIRST_HILBERT_RESOLUTION + 1;
    const anchor = hilbert.s_to_anchor(cell.s, @intCast(hilbert_resolution), quintant_orientation.orientation);
    return tiling.get_pentagon_vertices(hilbert_resolution, quintant_orientation.quintant, anchor);
}

pub fn cell_to_lonlat(cell: u64) Error!LonLat {
    if (cell == serialization.WORLD_CELL) {
        return LonLat.new(0.0, 0.0);
    }

    const cell_data = try serialization.deserialize(cell);
    const pentagon = get_pentagon(cell_data);
    const projection = try DodecahedronProjection.get_thread_local();
    const point = try projection.inverse(pentagon.get_center(), cell_data.origin_id);
    return ct.to_lon_lat(point);
}

pub fn cell_to_boundary(
    allocator: std.mem.Allocator,
    cell_id: u64,
    options: ?CellToBoundaryOptions,
) Error![]LonLat {
    if (cell_id == serialization.WORLD_CELL) {
        return allocator.alloc(LonLat, 0);
    }

    const opts = options orelse CellToBoundaryOptions{};
    const cell_data = try serialization.deserialize(cell_id);

    const default_segments: i32 = blk: {
        const exponent: u5 = @intCast(@max(@as(i32, 0), 6 - cell_data.resolution));
        break :blk @as(i32, 1) << exponent;
    };
    const requested_segments = @max(@as(i32, 1), opts.segments orelse default_segments);
    const edge_segments: usize = @intCast(@min(requested_segments, 25));

    const pentagon = get_pentagon(cell_data);
    const split_pentagon = pentagon.split_edges(edge_segments);
    const vertices = split_pentagon.get_vertices_vec();

    const projection = try DodecahedronProjection.get_thread_local();
    var boundary = try std.ArrayList(LonLat).initCapacity(allocator, vertices.len);
    defer boundary.deinit(allocator);

    for (vertices) |vertex| {
        const unprojected = try projection.inverse(vertex, cell_data.origin_id);
        try boundary.append(allocator, ct.to_lon_lat(unprojected));
    }

    var normalized_boundary = try ct.normalize_longitudes(allocator, boundary.items);

    if (opts.closed_ring and normalized_boundary.len > 0) {
        var closed = try allocator.alloc(LonLat, normalized_boundary.len + 1);
        @memcpy(closed[0..normalized_boundary.len], normalized_boundary);
        closed[normalized_boundary.len] = normalized_boundary[0];
        allocator.free(normalized_boundary);
        normalized_boundary = closed;
    }

    std.mem.reverse(LonLat, normalized_boundary);
    return normalized_boundary;
}

pub fn a5cell_contains_point(cell: A5Cell, point: LonLat) Error!f64 {
    const spherical = ct.from_lon_lat(point);
    const projection = try DodecahedronProjection.get_thread_local();
    const projected_point = try projection.forward(spherical, cell.origin_id);
    const quintant_orientation = core_origin.segment_to_quintant(cell.segment, get_origin_for_cell(cell));

    if (cell.resolution == serialization.FIRST_HILBERT_RESOLUTION - 1) {
        return tiling.get_quintant_vertices(quintant_orientation.quintant).contains_point(projected_point);
    }
    if (cell.resolution == serialization.FIRST_HILBERT_RESOLUTION - 2) {
        return tiling.get_face_vertices().contains_point(projected_point);
    }
    return get_pentagon(cell).contains_point(projected_point);
}
