const std = @import("std");
const coordinate_systems = @import("coordinate_systems");
const geometry = @import("geometry").pentagon;
const constants = @import("constants.zig");
const core_pentagon = @import("pentagon.zig");

const Face = coordinate_systems.Face;
const Polar = coordinate_systems.Polar;

const Mat2 = core_pentagon.Mat2;
const YES: i8 = -1;
const NO: i8 = 1;
const TRIANGLE_MODE = false;

fn shift_right() Face {
    return core_pentagon.w();
}

fn shift_left() Face {
    const w = core_pentagon.w();
    return Face.new(-w.x(), -w.y());
}

fn quintant_rotations() [5]Mat2 {
    var rotations = [_]Mat2{
        Mat2.new(1.0, 0.0, 0.0, 1.0),
        Mat2.new(1.0, 0.0, 0.0, 1.0),
        Mat2.new(1.0, 0.0, 0.0, 1.0),
        Mat2.new(1.0, 0.0, 0.0, 1.0),
        Mat2.new(1.0, 0.0, 0.0, 1.0),
    };

    var i: usize = 0;
    while (i < 5) : (i += 1) {
        const angle = constants.TWO_PI_OVER_5.get() * @as(f64, @floatFromInt(i));
        const cos_angle = std.math.cos(angle);
        const sin_angle = std.math.sin(angle);
        rotations[i] = Mat2.new(
            cos_angle,
            -sin_angle,
            sin_angle,
            cos_angle,
        );
    }
    return rotations;
}

fn transform_pentagon(shape: *geometry.PentagonShape, matrix: Mat2) void {
    const vertices = shape.get_vertices_vec();
    var transformed = [_]Face{Face.new(0.0, 0.0)} ** 128;
    var i: usize = 0;
    while (i < vertices.len) : (i += 1) {
        const vertex = vertices[i];
        transformed[i] = matrix.transform(vertex);
    }
    shape.set_vertices(transformed[0..vertices.len]);
}

pub fn get_pentagon_vertices(
    resolution: i32,
    quintant: usize,
    anchor: anytype,
) geometry.PentagonShape {
    var shape = if (TRIANGLE_MODE) core_pentagon.triangle() else core_pentagon.pentagon();

    const basis_mat = core_pentagon.basis();
    const translation = basis_mat.transform(Face.new(anchor.offset.x(), anchor.offset.y()));
    const flips = anchor.flips;
    const flip_0 = flips[0];
    const flip_1 = flips[1];

    if (flip_0 == NO and flip_1 == YES) {
        _ = shape.rotate180();
    }

    const f = flip_0 + flip_1;
    const k = anchor.k;
    if (((f == -2 or f == 2) and k > 1) or (f == 0 and (k == 0 or k == 3))) {
        _ = shape.reflect_y();
    }

    if (flip_0 == YES and flip_1 == YES) {
        _ = shape.rotate180();
    } else if (flip_0 == YES) {
        _ = shape.translate(shift_left());
    } else if (flip_1 == YES) {
        _ = shape.translate(shift_right());
    }

    _ = shape.translate(translation);
    const scale = 1.0 / std.math.pow(f64, 2.0, @as(f64, @floatFromInt(resolution)));
    _ = shape.scale(scale);

    const rotations = quintant_rotations();
    const rotation = rotations[quintant % 5];
    transform_pentagon(&shape, rotation);

    return shape;
}

pub fn get_quintant_vertices(quintant: usize) geometry.PentagonShape {
    const triangle = core_pentagon.triangle().get_vertices();
    var shape = geometry.PentagonShape.new_triangle(.{ triangle[0], triangle[1], triangle[2] });
    const rotations = quintant_rotations();
    transform_pentagon(&shape, rotations[quintant % 5]);
    return shape;
}

pub fn get_face_vertices() geometry.PentagonShape {
    const v = core_pentagon.v();
    const rotations = quintant_rotations();
    var vertices: [5]Face = undefined;
    var i: usize = 0;
    while (i < 5) : (i += 1) {
        vertices[i] = rotations[i].transform(v);
    }

    var left: usize = 0;
    var right: usize = 4;
    while (left < right) : ({
        left += 1;
        right -= 1;
    }) {
        std.mem.swap(Face, &vertices[left], &vertices[right]);
    }

    return geometry.PentagonShape.new(vertices);
}

pub fn get_quintant_polar(polar: Polar) usize {
    const gamma = polar.gamma().get();
    const raw = gamma / constants.TWO_PI_OVER_5.get();
    const shifted = std.math.floor(raw + 0.5);
    return @intCast(@mod(@as(i64, @intFromFloat(shifted)), 5));
}
