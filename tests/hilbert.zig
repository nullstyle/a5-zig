const std = @import("std");
const a5 = @import("a5");

const IJ = a5.coordinate_systems.IJ;
const KJ = a5.coordinate_systems.KJ;
const hilbert = a5.core.hilbert;

const Orientation = hilbert.Orientation;
const Quaternary = hilbert.Quaternary;
const NO = hilbert.NO;
const YES = hilbert.YES;

const TOLERANCE: f64 = 1e-6;

fn close_to(a: f64, b: f64, tolerance: f64) bool {
    return @abs(a - b) < tolerance;
}

fn close_to_ij(a: IJ, b: IJ, tolerance: f64) bool {
    return close_to(a.x(), b.x(), tolerance) and close_to(a.y(), b.y(), tolerance);
}

fn close_to_kj(a: KJ, b: KJ, tolerance: f64) bool {
    return close_to(a.x(), b.x(), tolerance) and close_to(a.y(), b.y(), tolerance);
}

fn anchor_equal(a: hilbert.Anchor, b: hilbert.Anchor) bool {
    return close_to_ij(a.offset, b.offset, TOLERANCE) and
        a.flips[0] == b.flips[0] and
        a.flips[1] == b.flips[1];
}

fn unique_offset_count(anchors: []const hilbert.Anchor) usize {
    var count: usize = 0;
    for (anchors, 0..) |anchor, i| {
        var seen = false;
        var j: usize = 0;
        while (j < i) : (j += 1) {
            if (close_to_ij(anchor.offset, anchors[j].offset, TOLERANCE)) {
                seen = true;
                break;
            }
        }
        if (!seen) {
            count += 1;
        }
    }
    return count;
}

fn unique_anchor_count(anchors: []const hilbert.Anchor) usize {
    var count: usize = 0;
    for (anchors, 0..) |anchor, i| {
        var seen = false;
        var j: usize = 0;
        while (j < i) : (j += 1) {
            if (anchor_equal(anchor, anchors[j])) {
                seen = true;
                break;
            }
        }
        if (!seen) {
            count += 1;
        }
    }
    return count;
}

fn bit_len(value: u64) usize {
    if (value == 0) return 1;
    var n = value;
    var len: usize = 0;
    while (n > 0) : (n >>= 1) {
        len += 1;
    }
    return len;
}

test "hilbert.quaternary_to_kj_base_cases" {
    const offset0 = hilbert.quaternary_to_kj(0, .{ NO, NO });
    try std.testing.expect(close_to_kj(offset0, KJ.new(0.0, 0.0), TOLERANCE));
    try std.testing.expectEqual([2]i8{ NO, NO }, hilbert.quaternary_to_flips(0));

    const offset1 = hilbert.quaternary_to_kj(1, .{ NO, NO });
    try std.testing.expect(close_to_kj(offset1, KJ.new(1.0, 0.0), TOLERANCE));
    try std.testing.expectEqual([2]i8{ NO, YES }, hilbert.quaternary_to_flips(1));

    const offset2 = hilbert.quaternary_to_kj(2, .{ NO, NO });
    try std.testing.expect(close_to_kj(offset2, KJ.new(1.0, 1.0), TOLERANCE));
    try std.testing.expectEqual([2]i8{ NO, NO }, hilbert.quaternary_to_flips(2));

    const offset3 = hilbert.quaternary_to_kj(3, .{ NO, NO });
    try std.testing.expect(close_to_kj(offset3, KJ.new(2.0, 1.0), TOLERANCE));
    try std.testing.expectEqual([2]i8{ YES, NO }, hilbert.quaternary_to_flips(3));
}

test "hilbert.quaternary_to_kj_with_flips" {
    const offset_x = hilbert.quaternary_to_kj(1, .{ YES, NO });
    try std.testing.expect(close_to_kj(offset_x, KJ.new(0.0, -1.0), TOLERANCE));

    const offset_y = hilbert.quaternary_to_kj(1, .{ NO, YES });
    try std.testing.expect(close_to_kj(offset_y, KJ.new(0.0, 1.0), TOLERANCE));

    const offset_xy = hilbert.quaternary_to_kj(1, .{ YES, YES });
    try std.testing.expect(close_to_kj(offset_xy, KJ.new(-1.0, 0.0), TOLERANCE));
}

test "hilbert.quaternary_to_flips_output_depends_only_on_n" {
    const expected = [_][2]i8{
        .{ NO, NO },
        .{ NO, YES },
        .{ NO, NO },
        .{ YES, NO },
    };
    for (expected, 0..) |e, n| {
        const flips = hilbert.quaternary_to_flips(@intCast(n));
        try std.testing.expectEqual(e, flips);
    }
}

test "hilbert.s_to_anchor_generates_correct_sequence" {
    const anchor0 = hilbert.s_to_anchor(0, 20, .UV);
    try std.testing.expect(close_to_ij(anchor0.offset, IJ.new(0.0, 0.0), TOLERANCE));
    try std.testing.expectEqual([2]i8{ NO, NO }, anchor0.flips);

    const anchor1 = hilbert.s_to_anchor(1, 20, .UV);
    try std.testing.expectEqual(YES, anchor1.flips[1]);

    const anchor4 = hilbert.s_to_anchor(4, 20, .UV);
    const offset_len = std.math.sqrt(anchor4.offset.x() * anchor4.offset.x() + anchor4.offset.y() * anchor4.offset.y());
    try std.testing.expect(offset_len > 1.0);

    var anchors: [16]hilbert.Anchor = undefined;
    for (0..anchors.len) |i| {
        anchors[i] = hilbert.s_to_anchor(i, 20, .UV);
    }

    try std.testing.expectEqual(@as(usize, 13), unique_offset_count(&anchors));
    try std.testing.expectEqual(@as(usize, 16), unique_anchor_count(&anchors));
}

test "hilbert.neighboring_anchors_are_adjacent" {
    const anchor1 = hilbert.s_to_anchor(0, 20, .UV);
    const anchor2 = hilbert.s_to_anchor(1, 20, .UV);
    const anchor3 = hilbert.s_to_anchor(2, 20, .UV);

    const diff = IJ.new(anchor2.offset.x() - anchor1.offset.x(), anchor2.offset.y() - anchor1.offset.y());
    const diff_len = std.math.sqrt(diff.x() * diff.x() + diff.y() * diff.y());
    try std.testing.expect(close_to(diff_len, 1.0, TOLERANCE));

    const diff2 = IJ.new(anchor3.offset.x() - anchor2.offset.x(), anchor3.offset.y() - anchor2.offset.y());
    const diff2_len = std.math.sqrt(diff2.x() * diff2.x() + diff2.y() * diff2.y());
    try std.testing.expect(close_to(diff2_len, 1.0, TOLERANCE));
}

test "hilbert.s_to_anchor_generates_correct_anchors_for_all_indices" {
    const ExpectedAnchor = struct {
        s: u64,
        offset: [2]f64,
        flips: [2]i8,
    };

    const expected = [_]ExpectedAnchor{
        .{ .s = 0, .offset = .{ 0.0, 0.0 }, .flips = .{ NO, NO } },
        .{ .s = 9, .offset = .{ 3.0, 1.0 }, .flips = .{ YES, YES } },
        .{ .s = 16, .offset = .{ 2.0, 2.0 }, .flips = .{ NO, NO } },
        .{ .s = 17, .offset = .{ 3.0, 2.0 }, .flips = .{ NO, YES } },
        .{ .s = 31, .offset = .{ 1.0, 3.0 }, .flips = .{ YES, NO } },
        .{ .s = 77, .offset = .{ 7.0, 5.0 }, .flips = .{ NO, NO } },
        .{ .s = 100, .offset = .{ 3.0, 7.0 }, .flips = .{ YES, YES } },
        .{ .s = 101, .offset = .{ 2.0, 7.0 }, .flips = .{ YES, NO } },
        .{ .s = 170, .offset = .{ 10.0, 1.0 }, .flips = .{ NO, NO } },
        .{ .s = 411, .offset = .{ 7.0, 13.0 }, .flips = .{ YES, NO } },
        .{ .s = 1762, .offset = .{ 7.0, 31.0 }, .flips = .{ YES, NO } },
        .{ .s = 481952, .offset = .{ 96.0, 356.0 }, .flips = .{ YES, YES } },
    };

    for (expected) |item| {
        const anchor = hilbert.s_to_anchor(item.s, 20, .UV);
        try std.testing.expect(close_to_ij(anchor.offset, IJ.new(item.offset[0], item.offset[1]), TOLERANCE));
        try std.testing.expectEqual(item.flips, anchor.flips);
    }
}

test "hilbert.ij_to_kj_converts_coordinates" {
    const TestCase = struct {
        input: [2]f64,
        expected: [2]f64,
    };
    const cases = [_]TestCase{
        .{ .input = .{ 0.0, 0.0 }, .expected = .{ 0.0, 0.0 } },
        .{ .input = .{ 1.0, 0.0 }, .expected = .{ 1.0, 0.0 } },
        .{ .input = .{ 0.0, 1.0 }, .expected = .{ 1.0, 1.0 } },
        .{ .input = .{ 1.0, 1.0 }, .expected = .{ 2.0, 1.0 } },
        .{ .input = .{ 2.0, 3.0 }, .expected = .{ 5.0, 3.0 } },
    };

    for (cases) |case| {
        const result = hilbert.ij_to_kj(IJ.new(case.input[0], case.input[1]));
        try std.testing.expect(close_to_kj(result, KJ.new(case.expected[0], case.expected[1]), TOLERANCE));
    }
}

test "hilbert.kj_to_ij_converts_coordinates" {
    const TestCase = struct {
        input: [2]f64,
        expected: [2]f64,
    };
    const cases = [_]TestCase{
        .{ .input = .{ 0.0, 0.0 }, .expected = .{ 0.0, 0.0 } },
        .{ .input = .{ 1.0, 0.0 }, .expected = .{ 1.0, 0.0 } },
        .{ .input = .{ 1.0, 1.0 }, .expected = .{ 0.0, 1.0 } },
        .{ .input = .{ 2.0, 1.0 }, .expected = .{ 1.0, 1.0 } },
        .{ .input = .{ 5.0, 3.0 }, .expected = .{ 2.0, 3.0 } },
    };

    for (cases) |case| {
        const result = hilbert.kj_to_ij(KJ.new(case.input[0], case.input[1]));
        try std.testing.expect(close_to_ij(result, IJ.new(case.expected[0], case.expected[1]), TOLERANCE));
    }
}

test "hilbert.ij_to_kj_and_kj_to_ij_are_inverses" {
    const points = [_][2]f64{
        .{ 0.0, 0.0 },
        .{ 1.0, 0.0 },
        .{ 0.0, 1.0 },
        .{ 1.0, 1.0 },
        .{ 2.0, 3.0 },
        .{ -1.0, 2.0 },
        .{ 3.0, -2.0 },
    };

    for (points) |point| {
        const original = IJ.new(point[0], point[1]);
        const kj = hilbert.ij_to_kj(original);
        const ij = hilbert.kj_to_ij(kj);
        try std.testing.expect(close_to_ij(original, ij, TOLERANCE));
    }
}

test "hilbert.get_required_digits_correctly_determines_digits_needed" {
    const TestCase = struct {
        offset: IJ,
        expected: usize,
    };
    const cases = [_]TestCase{
        .{ .offset = IJ.new(0.0, 0.0), .expected = 1 },
        .{ .offset = IJ.new(1.0, 0.0), .expected = 1 },
        .{ .offset = IJ.new(2.0, 1.0), .expected = 2 },
        .{ .offset = IJ.new(4.0, 0.0), .expected = 3 },
        .{ .offset = IJ.new(8.0, 8.0), .expected = 5 },
        .{ .offset = IJ.new(16.0, 0.0), .expected = 5 },
        .{ .offset = IJ.new(32.0, 32.0), .expected = 7 },
    };

    for (cases) |case| {
        try std.testing.expectEqual(case.expected, hilbert.get_required_digits(case.offset));
    }
}

test "hilbert.get_required_digits_matches_actual_digits_in_s_to_anchor_output" {
    const values = [_]u64{ 0, 1, 2, 3, 4, 9, 16, 17, 31, 77, 100 };
    for (values) |s| {
        const anchor = hilbert.s_to_anchor(s, 20, .UV);
        const required_digits = hilbert.get_required_digits(anchor.offset);
        const actual_digits: usize = if (s == 0) 1 else (bit_len(s) / 2 + 1);
        try std.testing.expect(required_digits >= actual_digits);
        try std.testing.expect(required_digits <= actual_digits + 1);
    }
}

test "hilbert.ij_to_s_computes_s_from_anchor" {
    const TestCase = struct {
        s: u64,
        offset: [2]f64,
    };
    const cases = [_]TestCase{
        .{ .s = 0, .offset = .{ 0.0, 0.0 } },
        .{ .s = 0, .offset = .{ 0.999, 0.0 } },
        .{ .s = 1, .offset = .{ 0.6, 0.6 } },
        .{ .s = 7, .offset = .{ 0.000001, 1.1 } },
        .{ .s = 2, .offset = .{ 1.2, 0.5 } },
        .{ .s = 2, .offset = .{ 1.9999, 0.0 } },
        .{ .s = 3, .offset = .{ 1.9999, 0.001 } },
        .{ .s = 4, .offset = .{ 1.1, 1.1 } },
        .{ .s = 5, .offset = .{ 1.999, 1.999 } },
        .{ .s = 6, .offset = .{ 0.99, 1.99 } },
        .{ .s = 28, .offset = .{ 0.999, 2.000001 } },
        .{ .s = 29, .offset = .{ 0.9, 2.5 } },
        .{ .s = 30, .offset = .{ 0.5, 3.1 } },
        .{ .s = 31, .offset = .{ 1.3, 2.5 } },
        .{ .s = 8, .offset = .{ 2.00001, 1.001 } },
        .{ .s = 9, .offset = .{ 2.8, 0.5 } },
        .{ .s = 10, .offset = .{ 2.00001, 0.5 } },
        .{ .s = 11, .offset = .{ 3.5, 0.2 } },
        .{ .s = 15, .offset = .{ 2.5, 1.5 } },
        .{ .s = 21, .offset = .{ 3.999, 3.999 } },
        .{ .s = 24, .offset = .{ 1.999, 3.999 } },
        .{ .s = 25, .offset = .{ 1.2, 3.5 } },
        .{ .s = 26, .offset = .{ 1.9, 2.2 } },
        .{ .s = 27, .offset = .{ 0.1, 3.9 } },
    };

    for (cases) |case| {
        const result = hilbert.ij_to_s(IJ.new(case.offset[0], case.offset[1]), 3, .UV);
        try std.testing.expectEqual(case.s, result);
    }
}

test "hilbert.ij_to_s_is_inverse_of_s_to_anchor" {
    const values = [_]u64{ 0, 1, 2, 3, 4, 9, 16, 17, 31, 77, 100, 101, 170, 411, 1762 };
    const resolution: usize = 20;
    const orientations = [_]Orientation{ .UV, .VU, .UW, .WU, .VW, .WV };

    for (orientations) |orientation| {
        for (values) |s| {
            var anchor = hilbert.s_to_anchor(s, resolution, orientation);
            const flip_x = anchor.flips[0];
            const flip_y = anchor.flips[1];

            if (flip_x == NO and flip_y == NO) {
                anchor.offset = IJ.new(anchor.offset.x() + 0.1, anchor.offset.y() + 0.1);
            } else if (flip_x == YES and flip_y == NO) {
                anchor.offset = IJ.new(anchor.offset.x() + 0.1, anchor.offset.y() - 0.2);
            } else if (flip_x == NO and flip_y == YES) {
                anchor.offset = IJ.new(anchor.offset.x() - 0.1, anchor.offset.y() + 0.2);
            } else if (flip_x == YES and flip_y == YES) {
                anchor.offset = IJ.new(anchor.offset.x() - 0.1, anchor.offset.y() - 0.1);
            }

            const result = hilbert.ij_to_s(anchor.offset, resolution, orientation);
            try std.testing.expectEqual(s, result);
        }
    }
}
