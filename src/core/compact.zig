const std = @import("std");
const cell_info = @import("cell_info.zig");
const serialization = @import("serialization.zig");

pub const Error = serialization.SerializationError || error{
    OutOfMemory,
    TargetResolutionTooLow,
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

pub fn uncompact(
    allocator: std.mem.Allocator,
    cells: []const u64,
    target_resolution: i32,
) Error![]u64 {
    var result_size: usize = 0;
    for (cells) |cell| {
        const resolution = serialization.get_resolution(cell);
        if (target_resolution < resolution) {
            return Error.TargetResolutionTooLow;
        }
        result_size += cell_info.get_num_children(resolution, target_resolution);
    }

    var result = try std.ArrayList(u64).initCapacity(allocator, result_size);
    errdefer result.deinit(allocator);

    for (cells) |cell| {
        const resolution = serialization.get_resolution(cell);
        const num_children = cell_info.get_num_children(resolution, target_resolution);

        if (num_children == 1) {
            try result.append(allocator, cell);
            continue;
        }

        const children = try serialization.cell_to_children(allocator, cell, target_resolution);
        defer allocator.free(children);
        try result.appendSlice(allocator, children);
    }

    return try result.toOwnedSlice(allocator);
}

pub fn compact(allocator: std.mem.Allocator, cells: []const u64) Error![]u64 {
    if (cells.len == 0) {
        return allocator.alloc(u64, 0);
    }

    var unique = std.AutoHashMap(u64, void).init(allocator);
    defer unique.deinit();
    for (cells) |cell| {
        try unique.put(cell, {});
    }

    var current = try allocator.alloc(u64, unique.count());
    var key_it = unique.keyIterator();
    var current_len: usize = 0;
    while (key_it.next()) |cell_ptr| {
        current[current_len] = cell_ptr.*;
        current_len += 1;
    }
    sort_u64(current);

    while (true) {
        var changed = false;
        var result = try std.ArrayList(u64).initCapacity(allocator, current.len);
        errdefer result.deinit(allocator);

        var i: usize = 0;
        while (i < current.len) {
            const cell = current[i];
            const resolution = serialization.get_resolution(cell);

            if (resolution < 0) {
                try result.append(allocator, cell);
                i += 1;
                continue;
            }

            const expected_children: usize = if (resolution >= serialization.FIRST_HILBERT_RESOLUTION)
                4
            else if (resolution == 0)
                12
            else
                5;

            if (i + expected_children <= current.len and serialization.is_first_child(cell, resolution)) {
                const stride = serialization.get_stride(resolution);
                var has_all_siblings = true;

                var j: usize = 1;
                while (j < expected_children) : (j += 1) {
                    const expected_cell = cell + @as(u64, @intCast(j)) * stride;
                    if (current[i + j] != expected_cell) {
                        has_all_siblings = false;
                        break;
                    }
                }

                if (has_all_siblings) {
                    const parent = try serialization.cell_to_parent(cell, null);
                    try result.append(allocator, parent);
                    i += expected_children;
                    changed = true;
                    continue;
                }
            }

            try result.append(allocator, cell);
            i += 1;
        }

        const next = try result.toOwnedSlice(allocator);
        sort_u64(next);
        allocator.free(current);
        current = next;

        if (!changed) {
            return current;
        }
    }
}
