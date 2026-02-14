const std = @import("std");
const origin = @import("origin.zig");
const utils = @import("utils.zig");

pub const A5Cell = utils.A5Cell;

pub const FIRST_HILBERT_RESOLUTION: i32 = 2;
pub const MAX_RESOLUTION: i32 = 30;
pub const HILBERT_START_BIT: u32 = 58;

pub const REMOVAL_MASK: u64 = 0x03ffffffffffffff;
pub const ORIGIN_SEGMENT_MASK: u64 = 0xfc00000000000000;
pub const ALL_ONES: u64 = 0xffffffffffffffff;

pub const WORLD_CELL: u64 = 0;

pub const SerializationError = error{
    OutOfMemory,
    InvalidOrigin,
    ResolutionTooLarge,
    STooLarge,
    ChildResolutionTooSmall,
    ChildResolutionTooLarge,
    ResolutionDifferenceTooLarge,
    ParentResolutionNegative,
    ParentResolutionTooLarge,
};

pub fn get_resolution(index: u64) i32 {
    var resolution: i32 = MAX_RESOLUTION - 1;
    var shifted: u64 = index >> 1;

    while (resolution > -1 and (shifted & 0b1) == 0) {
        resolution -= 1;
        const shift_by: u6 = if (resolution < FIRST_HILBERT_RESOLUTION) 1 else 2;
        shifted >>= shift_by;
    }

    return resolution;
}

pub fn deserialize(index: u64) SerializationError!A5Cell {
    const resolution = get_resolution(index);
    if (resolution == -1) {
        return .{
            .origin_id = 0,
            .segment = 0,
            .s = 0,
            .resolution = resolution,
        };
    }

    const top6_bits: usize = @intCast(index >> HILBERT_START_BIT);
    const origins = origin.get_origins();

    var origin_id: u8 = 0;
    var segment: usize = 0;

    if (resolution == 0) {
        if (top6_bits >= origins.len) {
            return SerializationError.InvalidOrigin;
        }
        origin_id = @intCast(top6_bits);
        segment = 0;
    } else {
        const origin_index = top6_bits / 5;
        if (origin_index >= origins.len) {
            return SerializationError.InvalidOrigin;
        }
        const face = origins[origin_index];
        origin_id = @intCast(origin_index);
        segment = (top6_bits + face.first_quintant) % 5;
    }

    if (resolution < FIRST_HILBERT_RESOLUTION) {
        return .{
            .origin_id = origin_id,
            .segment = segment,
            .s = 0,
            .resolution = resolution,
        };
    }

    const hilbert_levels = resolution - FIRST_HILBERT_RESOLUTION + 1;
    const hilbert_bits: u32 = @intCast(2 * hilbert_levels);
    const shift = HILBERT_START_BIT - hilbert_bits;
    const s = (index & REMOVAL_MASK) >> @intCast(shift);

    return .{
        .origin_id = origin_id,
        .segment = segment,
        .s = s,
        .resolution = resolution,
    };
}

pub fn serialize(cell: A5Cell) SerializationError!u64 {
    const origin_id = cell.origin_id;
    const segment = cell.segment;
    const s = cell.s;
    const resolution = cell.resolution;

    if (resolution > MAX_RESOLUTION) {
        return SerializationError.ResolutionTooLarge;
    }
    if (resolution == -1) {
        return WORLD_CELL;
    }

    const r: u32 = if (resolution < FIRST_HILBERT_RESOLUTION)
        @intCast(resolution + 1)
    else blk: {
        const hilbert_resolution = 1 + resolution - FIRST_HILBERT_RESOLUTION;
        break :blk @intCast(2 * hilbert_resolution + 1);
    };

    const origins = origin.get_origins();
    if (@as(usize, origin_id) >= origins.len) {
        return SerializationError.InvalidOrigin;
    }
    const face = origins[@as(usize, origin_id)];
    const segment_n = (segment + 5 - face.first_quintant) % 5;

    var index: u64 = if (resolution == 0)
        (@as(u64, origin_id) << HILBERT_START_BIT)
    else
        (@as(u64, @intCast(5 * @as(usize, origin_id) + segment_n)) << HILBERT_START_BIT);

    if (resolution >= FIRST_HILBERT_RESOLUTION) {
        const hilbert_levels = resolution - FIRST_HILBERT_RESOLUTION + 1;
        const hilbert_bits: u32 = @intCast(2 * hilbert_levels);

        const max_s: u64 = @as(u64, 1) << @intCast(hilbert_bits);
        if (s >= max_s) {
            return SerializationError.STooLarge;
        }

        index += s << @intCast(HILBERT_START_BIT - hilbert_bits);
    }

    index |= @as(u64, 1) << @intCast(HILBERT_START_BIT - r);
    return index;
}

pub fn cell_to_children(
    allocator: std.mem.Allocator,
    index: u64,
    child_resolution: ?i32,
) SerializationError![]u64 {
    const cell = try deserialize(index);
    const current_resolution = cell.resolution;
    const new_resolution = child_resolution orelse (current_resolution + 1);

    if (new_resolution < current_resolution) {
        return SerializationError.ChildResolutionTooSmall;
    }
    if (new_resolution > MAX_RESOLUTION) {
        return SerializationError.ChildResolutionTooLarge;
    }
    if (new_resolution == current_resolution) {
        var out = try allocator.alloc(u64, 1);
        out[0] = index;
        return out;
    }

    var origin_ids = [_]u8{0} ** 12;
    var origin_count: usize = 1;
    origin_ids[0] = cell.origin_id;

    if (current_resolution == -1) {
        origin_count = 12;
        for (0..12) |i| {
            origin_ids[i] = @intCast(i);
        }
    }

    var segments = [_]usize{0} ** 5;
    var segment_count: usize = 1;
    segments[0] = cell.segment;

    if ((current_resolution == -1 and new_resolution > 0) or current_resolution == 0) {
        segment_count = 5;
        segments = .{ 0, 1, 2, 3, 4 };
    }

    const anchor_resolution = @max(current_resolution, FIRST_HILBERT_RESOLUTION - 1);
    const resolution_diff = new_resolution - anchor_resolution;
    if (resolution_diff > 20) {
        return SerializationError.ResolutionDifferenceTooLarge;
    }

    var children_count: usize = 1;
    if (resolution_diff > 0) {
        var i: i32 = 0;
        while (i < resolution_diff) : (i += 1) {
            children_count *= 4;
        }
    }

    const shifted_s: u64 = if (resolution_diff > 0)
        cell.s << @intCast(2 * resolution_diff)
    else
        cell.s;

    var list = try std.ArrayList(u64).initCapacity(allocator, 0);
    errdefer list.deinit(allocator);

    for (origin_ids[0..origin_count]) |new_origin_id| {
        for (segments[0..segment_count]) |new_segment| {
            for (0..children_count) |i| {
                const new_cell = A5Cell{
                    .origin_id = new_origin_id,
                    .segment = new_segment,
                    .s = shifted_s + i,
                    .resolution = new_resolution,
                };
                try list.append(allocator, try serialize(new_cell));
            }
        }
    }

    return try list.toOwnedSlice(allocator);
}

pub fn cell_to_parent(index: u64, parent_resolution: ?i32) SerializationError!u64 {
    const cell = try deserialize(index);
    const current_resolution = cell.resolution;
    const new_resolution = parent_resolution orelse (current_resolution - 1);

    if (new_resolution == -1) {
        return WORLD_CELL;
    }
    if (new_resolution < 0) {
        return SerializationError.ParentResolutionNegative;
    }
    if (new_resolution > current_resolution) {
        return SerializationError.ParentResolutionTooLarge;
    }
    if (new_resolution == current_resolution) {
        return index;
    }

    const resolution_diff = current_resolution - new_resolution;
    const shifted_s = cell.s >> @intCast(2 * resolution_diff);
    return serialize(.{
        .origin_id = cell.origin_id,
        .segment = cell.segment,
        .s = shifted_s,
        .resolution = new_resolution,
    });
}

pub fn get_res0_cells(allocator: std.mem.Allocator) SerializationError![]u64 {
    return cell_to_children(allocator, WORLD_CELL, 0);
}

pub fn is_first_child(index: u64, resolution: ?i32) bool {
    const r = resolution orelse get_resolution(index);

    if (r < 2) {
        const top6_bits: usize = @intCast(index >> HILBERT_START_BIT);
        const child_count: usize = if (r == 0) 12 else 5;
        return (top6_bits % child_count) == 0;
    }

    const s_position: u32 = @intCast(2 * (MAX_RESOLUTION - r));
    const s_shift: u6 = @intCast(s_position);
    const s_mask: u64 = @as(u64, 3) << s_shift;
    return (index & s_mask) == 0;
}

pub fn get_stride(resolution: i32) u64 {
    if (resolution < 2) {
        return @as(u64, 1) << HILBERT_START_BIT;
    }
    const s_position: u32 = @intCast(2 * (MAX_RESOLUTION - resolution));
    return @as(u64, 1) << @intCast(s_position);
}
