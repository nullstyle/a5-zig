const std = @import("std");
const coordinate_systems = @import("coordinate_systems");

const IJ = coordinate_systems.IJ;
const KJ = coordinate_systems.KJ;

pub const Quaternary = u8;
pub const YES: i8 = -1;
pub const NO: i8 = 1;
pub const Flip = i8;

pub const Anchor = struct {
    k: Quaternary,
    offset: IJ,
    flips: [2]Flip,
};

pub const Orientation = enum {
    UV,
    VU,
    UW,
    WU,
    VW,
    WV,
};

const K_POS = KJ.new(1.0, 0.0);
const J_POS = KJ.new(0.0, 1.0);
const K_NEG = KJ.new(-1.0, 0.0);
const J_NEG = KJ.new(0.0, -1.0);
const ZERO = KJ.new(0.0, 0.0);

const FLIP_SHIFT = IJ.new(-1.0, 1.0);

const PATTERN = [_]usize{ 0, 1, 3, 4, 5, 6, 7, 2 };
const PATTERN_FLIPPED = [_]usize{ 0, 1, 2, 7, 3, 4, 5, 6 };

fn reversePattern(comptime pattern: [8]usize) [8]usize {
    var out: [8]usize = undefined;
    inline for (pattern, 0..) |value, i| {
        out[value] = i;
    }
    return out;
}

const PATTERN_REVERSED = reversePattern(PATTERN);
const PATTERN_FLIPPED_REVERSED = reversePattern(PATTERN_FLIPPED);

pub fn ij_to_kj(ij: IJ) KJ {
    return KJ.new(ij.x() + ij.y(), ij.y());
}

pub fn kj_to_ij(kj: KJ) IJ {
    return IJ.new(kj.x() - kj.y(), kj.y());
}

pub fn quaternary_to_kj(n: Quaternary, flips: [2]Flip) KJ {
    const flip_x = flips[0];
    const flip_y = flips[1];

    const pq: [2]KJ = switch (flip_x) {
        NO => switch (flip_y) {
            NO => .{ K_POS, J_POS },
            YES => .{ J_POS, K_POS },
            else => unreachable,
        },
        YES => switch (flip_y) {
            NO => .{ J_NEG, K_NEG },
            YES => .{ K_NEG, J_NEG },
            else => unreachable,
        },
        else => unreachable,
    };
    const p = pq[0];
    const q = pq[1];

    return switch (n) {
        0 => ZERO,
        1 => p,
        2 => KJ.new(q.x() + p.x(), q.y() + p.y()),
        3 => KJ.new(q.x() + 2.0 * p.x(), q.y() + 2.0 * p.y()),
        else => unreachable,
    };
}

pub fn quaternary_to_flips(n: Quaternary) [2]Flip {
    return switch (n) {
        0 => .{ NO, NO },
        1 => .{ NO, YES },
        2 => .{ NO, NO },
        3 => .{ YES, NO },
        else => unreachable,
    };
}

fn shift_digits(
    digits: []Quaternary,
    i: usize,
    flips: [2]Flip,
    invert_j: bool,
    pattern: []const usize,
) void {
    if (i == 0) {
        return;
    }

    const parent_k = digits[i];
    const child_k = digits[i - 1];
    const f = flips[0] + flips[1];

    var needs_shift = false;
    var first = false;
    if (invert_j != (f == 0)) {
        needs_shift = parent_k == 1 or parent_k == 2;
        first = parent_k == 1;
    } else {
        needs_shift = parent_k < 2;
        first = parent_k == 0;
    }

    if (!needs_shift) {
        return;
    }

    const src: usize = if (first) child_k else child_k + 4;
    const dst = pattern[src];
    digits[i - 1] = @intCast(dst % 4);
    digits[i] = @intCast((@as(usize, parent_k) + 4 + dst / 4 - src / 4) % 4);
}

pub fn s_to_anchor(s: u64, resolution: usize, orientation: Orientation) Anchor {
    const reverse = switch (orientation) {
        .VU, .WU, .VW => true,
        else => false,
    };
    const invert_j = switch (orientation) {
        .WV, .VW => true,
        else => false,
    };
    const flip_ij = switch (orientation) {
        .WU, .UW => true,
        else => false,
    };

    const adjusted_input = if (reverse) blk: {
        const shift: u6 = @intCast(2 * resolution);
        break :blk (@as(u64, 1) << shift) - s - 1;
    } else s;

    var anchor = s_to_anchor_internal(adjusted_input, resolution, invert_j, flip_ij);

    if (flip_ij) {
        const i = anchor.offset.x();
        const j = anchor.offset.y();
        anchor.offset = IJ.new(j, i);

        if (anchor.flips[0] == YES) {
            anchor.offset = IJ.new(
                anchor.offset.x() + FLIP_SHIFT.x(),
                anchor.offset.y() + FLIP_SHIFT.y(),
            );
        }
        if (anchor.flips[1] == YES) {
            anchor.offset = IJ.new(
                anchor.offset.x() - FLIP_SHIFT.x(),
                anchor.offset.y() - FLIP_SHIFT.y(),
            );
        }
    }

    if (invert_j) {
        const i = anchor.offset.x();
        const j = anchor.offset.y();
        const scale = @as(f64, @floatFromInt(@as(u64, 1) << @intCast(resolution)));
        const new_j = scale - (i + j);
        anchor.flips[0] = -anchor.flips[0];
        anchor.offset = IJ.new(i, new_j);
    }

    return anchor;
}

pub fn s_to_anchor_internal(s: u64, resolution: usize, invert_j: bool, flip_ij: bool) Anchor {
    var offset = ZERO;
    var flips = [2]Flip{ NO, NO };
    var input = s;

    var digits = [_]Quaternary{0} ** 64;
    var digits_len: usize = 0;
    while (input > 0 or digits_len < resolution) {
        digits[digits_len] = @intCast(input % 4);
        digits_len += 1;
        input >>= 2;
    }

    const pattern: []const usize = if (flip_ij)
        &PATTERN_FLIPPED
    else
        &PATTERN;

    var i = digits_len;
    while (i > 0) {
        i -= 1;
        shift_digits(digits[0..digits_len], i, flips, invert_j, pattern);
        const next_flips = quaternary_to_flips(digits[i]);
        flips[0] *= next_flips[0];
        flips[1] *= next_flips[1];
    }

    flips = .{ NO, NO };
    i = digits_len;
    while (i > 0) {
        i -= 1;
        offset = KJ.new(offset.x() * 2.0, offset.y() * 2.0);
        const child_offset = quaternary_to_kj(digits[i], flips);
        offset = KJ.new(offset.x() + child_offset.x(), offset.y() + child_offset.y());

        const next_flips = quaternary_to_flips(digits[i]);
        flips[0] *= next_flips[0];
        flips[1] *= next_flips[1];
    }

    const k: Quaternary = if (digits_len > 0) digits[0] else 0;

    return .{
        .k = k,
        .offset = kj_to_ij(offset),
        .flips = flips,
    };
}

pub fn get_required_digits(offset: IJ) usize {
    const index_sum = @ceil(offset.x()) + @ceil(offset.y());
    if (index_sum == 0.0) {
        return 1;
    }
    return 1 + @as(usize, @intFromFloat(@floor(std.math.log2(index_sum))));
}

pub fn ij_to_quaternary(ij: IJ, flips: [2]Flip) Quaternary {
    const u = ij.x();
    const v = ij.y();

    const a = if (flips[0] == YES) -(u + v) else (u + v);
    const b = if (flips[1] == YES) -u else u;
    const c = if (flips[0] == YES) -v else v;

    if (flips[0] + flips[1] == 0) {
        if (c < 1.0) {
            return 0;
        } else if (b > 1.0) {
            return 3;
        } else if (a > 1.0) {
            return 2;
        } else {
            return 1;
        }
    } else if (a < 1.0) {
        return 0;
    } else if (b > 1.0) {
        return 3;
    } else if (c > 1.0) {
        return 2;
    } else {
        return 1;
    }
}

pub fn ij_to_s(input: IJ, resolution: usize, orientation: Orientation) u64 {
    const reverse = switch (orientation) {
        .VU, .WU, .VW => true,
        else => false,
    };
    const invert_j = switch (orientation) {
        .WV, .VW => true,
        else => false,
    };
    const flip_ij = switch (orientation) {
        .WU, .UW => true,
        else => false,
    };

    var ij = input;
    if (flip_ij) {
        ij = IJ.new(input.y(), input.x());
    }
    if (invert_j) {
        const i = ij.x();
        const j = ij.y();
        const scale = @as(f64, @floatFromInt(@as(u64, 1) << @intCast(resolution)));
        ij = IJ.new(i, scale - (i + j));
    }

    const s = ij_to_s_internal(ij, invert_j, flip_ij, resolution);
    if (reverse) {
        const shift: u6 = @intCast(2 * resolution);
        return (@as(u64, 1) << shift) - s - 1;
    }
    return s;
}

pub fn ij_to_s_internal(input: IJ, invert_j: bool, flip_ij: bool, resolution: usize) u64 {
    const num_digits = resolution;
    var digits = [_]Quaternary{0} ** 64;

    var flips = [2]Flip{ NO, NO };
    var pivot = IJ.new(0.0, 0.0);

    var i = num_digits;
    while (i > 0) {
        i -= 1;
        const relative_offset = IJ.new(input.x() - pivot.x(), input.y() - pivot.y());
        const scale = 1.0 / @as(f64, @floatFromInt(@as(u64, 1) << @intCast(i)));
        const scaled_offset = IJ.new(relative_offset.x() * scale, relative_offset.y() * scale);
        const digit = ij_to_quaternary(scaled_offset, flips);
        digits[i] = digit;

        const child_offset = kj_to_ij(quaternary_to_kj(digit, flips));
        const upscale = @as(f64, @floatFromInt(@as(u64, 1) << @intCast(i)));
        const upscaled_child_offset = IJ.new(child_offset.x() * upscale, child_offset.y() * upscale);
        pivot = IJ.new(
            pivot.x() + upscaled_child_offset.x(),
            pivot.y() + upscaled_child_offset.y(),
        );

        const next_flips = quaternary_to_flips(digit);
        flips[0] *= next_flips[0];
        flips[1] *= next_flips[1];
    }

    const pattern: []const usize = if (flip_ij)
        &PATTERN_FLIPPED_REVERSED
    else
        &PATTERN_REVERSED;

    for (0..num_digits) |digit_i| {
        const next_flips = quaternary_to_flips(digits[digit_i]);
        flips[0] *= next_flips[0];
        flips[1] *= next_flips[1];
        shift_digits(digits[0..num_digits], digit_i, flips, invert_j, pattern);
    }

    var output: u64 = 0;
    i = num_digits;
    while (i > 0) {
        i -= 1;
        output += @as(u64, digits[i]) << @intCast(2 * i);
    }

    return output;
}
