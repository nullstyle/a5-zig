const std = @import("std");
const a5 = @import("a5");
const support = @import("a5_test_support");
const support_fixtures = support.fixtures;

const dq = a5.core.dodecahedron_quaternions;

const TOLERANCE = 1e-10;

const TransformFixture = struct {
    orthogonalityTest: f64,
};

const QuaternionFixture = struct {
    index: usize,
    quaternion: [4]f64,
    magnitude: f64,
    normalized: [4]f64,
    faceCenter: [3]f64,
    testTransforms: TransformFixture,
};

const RingFixture = struct {
    indices: []const usize,
    zValues: []const f64,
    expectedZ: f64,
};

const RingsFixture = struct {
    firstRing: RingFixture,
    secondRing: RingFixture,
};

const MetadataFixture = struct {
    totalQuaternions: usize,
};

const ConstantsFixture = struct {
    INV_SQRT5: f64,
    cosAlpha: f64,
    sinAlpha: f64,
    expectedPentagonAngle: f64,
};

const Fixture = struct {
    quaternions: []const QuaternionFixture,
    rings: RingsFixture,
    constants: ConstantsFixture,
    metadata: MetadataFixture,
};

fn loadFixture() !std.json.Parsed(Fixture) {
    return support_fixtures.parseFixture(Fixture, "dodecahedron-quaternions.json", std.testing.allocator);
}

fn quatLength(q: [4]f64) f64 {
    return std.math.sqrt((q[0] * q[0]) + (q[1] * q[1]) + (q[2] * q[2]) + (q[3] * q[3]));
}

fn quatMagnitude(q: [4]f64) f64 {
    return quatLength(q);
}

fn quatRotateVector(quat: [4]f64, vec: [3]f64) [3]f64 {
    const qx = quat[0];
    const qy = quat[1];
    const qz = quat[2];
    const qw = quat[3];

    const vx = vec[0];
    const vy = vec[1];
    const vz = vec[2];

    const t1_x = (qw * vx) + (qy * vz) - (qz * vy);
    const t1_y = (qw * vy) + (qz * vx) - (qx * vz);
    const t1_z = (qw * vz) + (qx * vy) - (qy * vx);
    const t1_w = -qx * vx - qy * vy - qz * vz;

    const result_x = (t1_x * qw) + (t1_w * -qx) + (t1_y * -qz) - (t1_z * -qy);
    const result_y = (t1_y * qw) + (t1_w * -qy) + (t1_z * -qx) - (t1_x * -qz);
    const result_z = (t1_z * qw) + (t1_w * -qz) + (t1_x * -qy) - (t1_y * -qx);

    return .{ result_x, result_y, result_z };
}

fn vectorMagnitude(vec: [3]f64) f64 {
    return std.math.sqrt((vec[0] * vec[0]) + (vec[1] * vec[1]) + (vec[2] * vec[2]));
}

fn vectorDistance(a: [3]f64, b: [3]f64) f64 {
    return vectorMagnitude(.{
        a[0] - b[0],
        a[1] - b[1],
        a[2] - b[2],
    });
}

fn vectorDot(a: [3]f64, b: [3]f64) f64 {
    return (a[0] * b[0]) + (a[1] * b[1]) + (a[2] * b[2]);
}

test "quaternion array should include all 12 quaternions" {
    var parsed = try loadFixture();
    defer parsed.deinit();
    const fixture = parsed.value;

    try std.testing.expectEqual(fixture.metadata.totalQuaternions, dq.QUATERNIONS.len);
    try std.testing.expectEqual(@as(f64, dq.QUATERNIONS[0][3]), 1.0);
    try std.testing.expect(std.math.approxEqAbs(f64, dq.QUATERNIONS[11][0], 0.0, TOLERANCE));
}

test "all quaternions are normalized and match fixture" {
    var parsed = try loadFixture();
    defer parsed.deinit();
    const fixture = parsed.value;

    try std.testing.expectEqual(fixture.quaternions.len, dq.QUATERNIONS.len);
    for (fixture.quaternions) |data| {
        const actual_length = quatMagnitude(data.quaternion);
        const normalized_length = quatMagnitude(data.normalized);
        try std.testing.expect(std.math.approxEqAbs(f64, data.magnitude, actual_length, TOLERANCE));
        try std.testing.expect(std.math.approxEqAbs(f64, data.normalized[3], dq.QUATERNIONS[data.index][3], TOLERANCE));
        try std.testing.expect(std.math.approxEqAbs(f64, 1.0, actual_length, TOLERANCE));
        try std.testing.expect(std.math.approxEqAbs(f64, 1.0, normalized_length, TOLERANCE));
    }
}

test "quaternions should be finite and valid" {
    var parsed = try loadFixture();
    defer parsed.deinit();

    for (parsed.value.quaternions) |data| {
        for (data.quaternion) |component| {
            try std.testing.expect(std.math.isFinite(component));
            try std.testing.expect(!std.math.isNan(component));
        }
    }
}

test "first ring quaternion structure should be valid" {
    var parsed = try loadFixture();
    defer parsed.deinit();

    for (dq.QUATERNIONS[1..6], 0..) |q, i| {
        try std.testing.expect(std.math.approxEqAbs(f64, q[2], 0.0, 1e-15));
        try std.testing.expect(std.math.approxEqAbs(f64, q[3], parsed.value.constants.cosAlpha, 1e-10));
        try std.testing.expect(i < 5);
    }
}

test "second ring quaternion structure should be valid" {
    var parsed = try loadFixture();
    defer parsed.deinit();

    for (dq.QUATERNIONS[6..11]) |q| {
        try std.testing.expect(std.math.approxEqAbs(f64, q[2], 0.0, 1e-15));
        try std.testing.expect(std.math.approxEqAbs(f64, q[3], parsed.value.constants.sinAlpha, 1e-10));
    }
}

test "quaternion rotation should preserve unit vectors" {
    var parsed = try loadFixture();
    defer parsed.deinit();

    const north_pole = [3]f64{ 0.0, 0.0, 1.0 };
    const x_axis = [3]f64{ 1.0, 0.0, 0.0 };
    const y_axis = [3]f64{ 0.0, 1.0, 0.0 };

    for (dq.QUATERNIONS, 0..) |q, i| {
        const rotated = quatRotateVector(q, north_pole);
        const rotated_x = quatRotateVector(q, x_axis);
        const rotated_y = quatRotateVector(q, y_axis);
        const rotated_length = vectorMagnitude(rotated);
        const rotated_x_len = vectorMagnitude(rotated_x);
        const rotated_y_len = vectorMagnitude(rotated_y);

        try std.testing.expect(std.math.approxEqAbs(f64, rotated_length, 1.0, TOLERANCE));
        try std.testing.expect(std.math.approxEqAbs(f64, rotated_x_len, 1.0, TOLERANCE));
        try std.testing.expect(std.math.approxEqAbs(f64, rotated_y_len, 1.0, TOLERANCE));

        if (i != 0) {
            const distance = vectorDistance(rotated, north_pole);
            try std.testing.expect(distance > 0.1);
        }
    }
}

test "quaternions should produce distinct face centers" {
    const north_pole = [3]f64{ 0.0, 0.0, 1.0 };

    var centers: [12][3]f64 = undefined;
    var i: usize = 0;
    while (i < dq.QUATERNIONS.len) : (i += 1) {
        centers[i] = quatRotateVector(dq.QUATERNIONS[i], north_pole);
    }

    var a: usize = 0;
    while (a < centers.len) : (a += 1) {
        var b: usize = a + 1;
        while (b < centers.len) : (b += 1) {
            const distance = vectorDistance(centers[a], centers[b]);
            try std.testing.expect(distance > 0.1);
        }
    }
}

test "quaternion conjugate should reverse rotation" {
    const test_vector = [3]f64{ 1.0, 0.0, 0.0 };

    for (dq.QUATERNIONS) |q| {
        const conjugate = [_]f64{ -q[0], -q[1], -q[2], q[3] };
        const rotated = quatRotateVector(q, test_vector);
        const unrotated = quatRotateVector(conjugate, rotated);
        const distance = vectorDistance(test_vector, unrotated);
        try std.testing.expect(std.math.approxEqAbs(f64, distance, 0.0, TOLERANCE));
    }
}

test "quaternion transform should preserve orthogonality" {
    const v1 = [3]f64{ 1.0, 0.0, 0.0 };
    const v2 = [3]f64{ 0.0, 1.0, 0.0 };

    for (dq.QUATERNIONS) |q| {
        const r1 = quatRotateVector(q, v1);
        const r2 = quatRotateVector(q, v2);
        const dot = vectorDot(r1, r2);
        try std.testing.expect(std.math.approxEqAbs(f64, dot, 0.0, TOLERANCE));
    }
}

test "quaternion transform should preserve vector magnitudes" {
    const vectors = [_][3]f64{
        .{ 1.0, 0.0, 0.0 },
        .{ 0.0, 1.0, 0.0 },
        .{ 0.0, 0.0, 1.0 },
        .{ 1.0, 1.0, 1.0 },
    };

    for (dq.QUATERNIONS) |q| {
        for (vectors) |vec| {
            const rotated = quatRotateVector(q, vec);
            const original = vectorMagnitude(vec);
            const transformed = vectorMagnitude(rotated);
            try std.testing.expect(std.math.approxEqAbs(f64, original, transformed, TOLERANCE));
        }
    }
}

test "face center distribution should include two ring levels" {
    var parsed = try loadFixture();
    defer parsed.deinit();

    const north_pole = [3]f64{ 0.0, 0.0, 1.0 };
    const south_pole = [3]f64{ 0.0, 0.0, -1.0 };

    var count_north: usize = 0;
    var count_south: usize = 0;
    var first_ring: usize = 0;
    var second_ring: usize = 0;

    for (dq.QUATERNIONS) |q| {
        const face_center = quatRotateVector(q, north_pole);
        if (std.math.approxEqAbs(f64, face_center[2], 1.0, 1e-10)) {
            count_north += 1;
        } else if (std.math.approxEqAbs(f64, face_center[2], -1.0, 1e-10)) {
            count_south += 1;
        } else if (std.math.approxEqAbs(f64, face_center[2], parsed.value.rings.firstRing.expectedZ, 1e-5) or
            std.math.approxEqAbs(f64, face_center[2], parsed.value.rings.secondRing.expectedZ, 1e-5))
        {
            if (std.math.approxEqAbs(f64, face_center[2], parsed.value.rings.firstRing.expectedZ, 1e-5)) {
                first_ring += 1;
            } else {
                second_ring += 1;
            }
        }
    }

    try std.testing.expectEqual(@as(usize, 1), count_north);
    try std.testing.expectEqual(@as(usize, 1), count_south);
    try std.testing.expectEqual(@as(usize, 5), first_ring);
    try std.testing.expectEqual(@as(usize, 5), second_ring);

    _ = south_pole;
}

test "quaternions should form regular pentagonal arrangements" {
    var parsed = try loadFixture();
    defer parsed.deinit();
    const fixture = parsed.value;

    const north_pole = [3]f64{ 0.0, 0.0, 1.0 };
    var first_ring: [5][3]f64 = undefined;
    var i: usize = 0;
    while (i < 5) : (i += 1) {
        const q = dq.QUATERNIONS[i + 1];
        first_ring[i] = quatRotateVector(q, north_pole);
    }

    for (0..5) |index| {
        const next_index = (index + 1) % 5;
        const angle1 = std.math.atan2(first_ring[index][1], first_ring[index][0]);
        const angle2 = std.math.atan2(first_ring[next_index][1], first_ring[next_index][0]);
        var angle_diff = angle2 - angle1;
        if (angle_diff < 0.0) {
            angle_diff += 2.0 * std.math.pi;
        }
        if (angle_diff > std.math.pi) {
            angle_diff = 2.0 * std.math.pi - angle_diff;
        }
        try std.testing.expect(std.math.approxEqAbs(f64, angle_diff, fixture.constants.expectedPentagonAngle, 0.1));
    }
}

test "fixture metadata should be consistent" {
    var parsed = try loadFixture();
    defer parsed.deinit();
    const fixture = parsed.value;

    try std.testing.expectEqual(fixture.metadata.totalQuaternions, dq.QUATERNIONS.len);
    try std.testing.expect(std.math.approxEqAbs(f64, fixture.constants.INV_SQRT5, std.math.sqrt(0.2), 1e-15));
    try std.testing.expect(std.math.approxEqAbs(f64, fixture.constants.expectedPentagonAngle, 2.0 * std.math.pi / 5.0, 1e-15));
}
