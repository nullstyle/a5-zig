const std = @import("std");
const coordinate_systems = @import("coordinate_systems");
const constants = @import("constants.zig");
const dodecahedron_quaternions = @import("dodecahedron_quaternions.zig");
const hilbert = @import("hilbert.zig");
const utils = @import("utils.zig");

const Origin = utils.Origin;
const Quat = utils.Quat;
const Orientation = hilbert.Orientation;
const Radians = coordinate_systems.Radians;
const Spherical = coordinate_systems.Spherical;

pub const QuintantToSegment = struct {
    segment: usize,
    orientation: Orientation,
};
pub const SegmentToQuintant = struct {
    quintant: usize,
    orientation: Orientation,
};

const CLOCKWISE_FAN: [5]Orientation = .{ .VU, .UW, .VW, .VW, .VW };
const CLOCKWISE_STEP: [5]Orientation = .{ .WU, .UW, .VW, .VU, .UW };
const COUNTER_STEP: [5]Orientation = .{ .WU, .UV, .WV, .WU, .UW };
const COUNTER_JUMP: [5]Orientation = .{ .VU, .UV, .WV, .WU, .UW };

const QUINTANT_ORIENTATIONS_ARRAYS: [12][5]Orientation = .{
    CLOCKWISE_FAN,
    COUNTER_JUMP,
    COUNTER_STEP,
    CLOCKWISE_STEP,
    COUNTER_STEP,
    COUNTER_JUMP,
    COUNTER_STEP,
    CLOCKWISE_STEP,
    CLOCKWISE_STEP,
    CLOCKWISE_STEP,
    COUNTER_JUMP,
    COUNTER_JUMP,
};

const QUINTANT_FIRST: [12]usize = .{ 4, 2, 3, 2, 0, 4, 3, 2, 2, 0, 3, 0 };
const ORIGIN_ORDER: [12]usize = .{ 0, 1, 2, 4, 3, 5, 7, 8, 6, 11, 10, 9 };

fn quatConjugate(quat: Quat) Quat {
    return .{ -quat[0], -quat[1], -quat[2], quat[3] };
}

fn addOrigin(
    destination: *[12]Origin,
    origin_id: *usize,
    axis: Spherical,
    angle: Radians,
    quaternion: Quat,
) void {
    const id = origin_id.*;
    destination[id] = .{
        .id = @intCast(id),
        .axis = axis,
        .quat = quaternion,
        .inverse_quat = quatConjugate(quaternion),
        .angle = angle,
        .orientation = QUINTANT_ORIENTATIONS_ARRAYS[id],
        .first_quintant = QUINTANT_FIRST[id],
    };
    origin_id.* = id + 1;
}

fn generateOrigins() [12]Origin {
    var generated = [_]Origin{getFallbackOrigin()} ** 12;
    var origin_id: usize = 0;

    addOrigin(
        &generated,
        &origin_id,
        Spherical.new(
            Radians.new_unchecked(0.0),
            Radians.new_unchecked(0.0),
        ),
        Radians.new_unchecked(0.0),
        dodecahedron_quaternions.QUATERNIONS[0],
    );

    var i: usize = 0;
    while (i < 5) : (i += 1) {
        const alpha = @as(f64, @floatFromInt(i)) * constants.TWO_PI_OVER_5.get();
        addOrigin(
            &generated,
            &origin_id,
            Spherical.new(
                Radians.new_unchecked(alpha),
                constants.INTERHEDRAL_ANGLE,
            ),
            Radians.new_unchecked(constants.PI_OVER_5.get()),
            dodecahedron_quaternions.QUATERNIONS[i + 1],
        );
        addOrigin(
            &generated,
            &origin_id,
            Spherical.new(
                Radians.new_unchecked(alpha + constants.PI_OVER_5.get()),
                Radians.new_unchecked(std.math.pi - constants.INTERHEDRAL_ANGLE.get()),
            ),
            Radians.new_unchecked(constants.PI_OVER_5.get()),
            dodecahedron_quaternions.QUATERNIONS[(i + 3) % 5 + 6],
        );
    }

    addOrigin(
        &generated,
        &origin_id,
        Spherical.new(
            Radians.new_unchecked(0.0),
            Radians.new_unchecked(std.math.pi),
        ),
        Radians.new_unchecked(0.0),
        dodecahedron_quaternions.QUATERNIONS[11],
    );

    var reordered = [_]Origin{getFallbackOrigin()} ** 12;
    for (ORIGIN_ORDER, 0..) |original_id, new_id| {
        var origin = generated[original_id];
        origin.id = @intCast(new_id);
        reordered[new_id] = origin;
    }

    return reordered;
}

fn getFallbackOrigin() Origin {
    return Origin{
        .id = 0,
        .axis = Spherical.new(
            Radians.new_unchecked(0.0),
            Radians.new_unchecked(0.0),
        ),
        .quat = .{ 0.0, 0.0, 0.0, 1.0 },
        .inverse_quat = .{ 0.0, 0.0, 0.0, 1.0 },
        .angle = Radians.new_unchecked(0.0),
        .orientation = .{ .VU, .UW, .VW, .VW, .VW },
        .first_quintant = 4,
    };
}

var origins_cache: ?[12]Origin = null;

fn getOriginsCache() *const [12]Origin {
    if (origins_cache == null) {
        origins_cache = generateOrigins();
    }
    return &origins_cache.?;
}

pub fn get_origins() []const Origin {
    return getOriginsCache()[0..];
}

fn isLayoutClockwise(layout: [5]Orientation) bool {
    return std.mem.eql(Orientation, layout[0..], CLOCKWISE_FAN[0..]) or
        std.mem.eql(Orientation, layout[0..], CLOCKWISE_STEP[0..]);
}

pub fn quintant_to_segment(quintant: usize, origin: Origin) QuintantToSegment {
    const layout = origin.orientation;
    const is_clockwise = isLayoutClockwise(layout);
    const step: i32 = if (is_clockwise) -1 else 1;
    const delta: usize = (quintant + 5 - origin.first_quintant) % 5;
    const face_relative_quintant: usize = @intCast(@mod(step * @as(i32, @intCast(delta)) + 5, 5));
    const orientation = layout[face_relative_quintant];
    const segment = (origin.first_quintant + face_relative_quintant) % 5;
    return .{ .segment = segment, .orientation = orientation };
}

pub fn segment_to_quintant(segment: usize, origin: Origin) SegmentToQuintant {
    const layout = origin.orientation;
    const is_clockwise = isLayoutClockwise(layout);
    const step: i32 = if (is_clockwise) -1 else 1;
    const face_relative_quintant: usize = (segment + 5 - origin.first_quintant) % 5;
    const orientation = layout[face_relative_quintant];

    const step_offset: i32 = step * @as(i32, @intCast(face_relative_quintant));
    const quintant: usize = if (step_offset >= 0)
        (origin.first_quintant + @as(usize, @intCast(step_offset))) % 5
    else
        (origin.first_quintant + 5 - @as(usize, @intCast(-step_offset))) % 5;

    return .{ .quintant = quintant, .orientation = orientation };
}

pub fn find_nearest_origin(point: Spherical) Origin {
    const origins = get_origins();
    const tie_epsilon = 1e-15;
    var min_distance = std.math.inf(f64);
    var nearest = origins[0];

    for (origins) |origin| {
        const distance = haversine(point, origin.axis);
        const diff = distance - min_distance;
        if (diff < -tie_epsilon or
            (@abs(diff) <= tie_epsilon and origin.id < nearest.id))
        {
            min_distance = distance;
            nearest = origin;
        }
    }

    return nearest;
}

pub fn is_nearest_origin(point: Spherical, origin: Origin) bool {
    return haversine(point, origin.axis) > 0.49999999;
}

pub fn haversine(point: Spherical, axis: Spherical) f64 {
    const theta = point.theta().get();
    const phi = point.phi().get();
    const theta2 = axis.theta().get();
    const phi2 = axis.phi().get();
    const dtheta = theta2 - theta;
    const dphi = phi2 - phi;
    const a1 = std.math.sin(dphi / 2.0);
    const a2 = std.math.sin(dtheta / 2.0);
    return (a1 * a1) + (a2 * a2 * std.math.sin(phi) * std.math.sin(phi2));
}
