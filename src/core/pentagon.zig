const std = @import("std");
const coordinate_systems = @import("coordinate_systems");
const constants = @import("constants.zig");
const geometry = @import("geometry").pentagon;

const Face = coordinate_systems.Face;
const Degrees = coordinate_systems.Degrees;
const Radians = coordinate_systems.Radians;

pub const A: Degrees = Degrees.new_unchecked(72.0);
pub const B: Degrees = Degrees.new_unchecked(127.94543761193603);
pub const C: Degrees = Degrees.new_unchecked(108.0);
pub const D: Degrees = Degrees.new_unchecked(82.29202980963508);
pub const E: Degrees = Degrees.new_unchecked(149.7625318412527);

pub const PentagonVertices = struct {
    a: Face,
    b: Face,
    c: Face,
    d: Face,
    e: Face,
};

pub const TriangleVertices = struct {
    u: Face,
    v: Face,
    w: Face,
    v_angle: Radians,
};

pub const Mat2 = struct {
    m00: f64,
    m01: f64,
    m10: f64,
    m11: f64,

    pub fn new(m00: f64, m01: f64, m10: f64, m11: f64) Mat2 {
        return .{ .m00 = m00, .m01 = m01, .m10 = m10, .m11 = m11 };
    }

    pub fn from_cols(col0: Face, col1: Face) Mat2 {
        return .{
            .m00 = col0.x(),
            .m01 = col1.x(),
            .m10 = col0.y(),
            .m11 = col1.y(),
        };
    }

    pub fn determinant(self: Mat2) f64 {
        return self.m00 * self.m11 - self.m01 * self.m10;
    }

    pub fn inverse(self: Mat2) ?Mat2 {
        const det = self.determinant();
        if (@abs(det) < std.math.floatEps(f64)) return null;
        const inv_det = 1.0 / det;
        return .{
            .m00 = self.m11 * inv_det,
            .m01 = -self.m01 * inv_det,
            .m10 = -self.m10 * inv_det,
            .m11 = self.m00 * inv_det,
        };
    }

    pub fn transform(self: Mat2, vector: Face) Face {
        return Face.new(
            self.m00 * vector.x() + self.m01 * vector.y(),
            self.m10 * vector.x() + self.m11 * vector.y(),
        );
    }
};

const PentagonConstants = struct {
    vertices: PentagonVertices,
    pentagon: geometry.PentagonShape,
    triangle_vertices: TriangleVertices,
    triangle: geometry.PentagonShape,
    basis: Mat2,
    basis_inverse: Mat2,
};

fn make_constants() PentagonConstants {
    var corner_a = Face.new(0.0, 0.0);
    var corner_b = Face.new(0.0, 1.0);
    var corner_c = Face.new(0.7885966681787006, 1.6149108024237764);
    var corner_d = Face.new(1.6171013659387945, 1.054928690397459);
    var corner_e = Face.new(std.math.cos(constants.PI_OVER_10.get()), std.math.sin(constants.PI_OVER_10.get()));

    const c_length = std.math.sqrt(corner_c.x() * corner_c.x() + corner_c.y() * corner_c.y());
    const edge_midpoint_d = 2.0 * c_length * std.math.cos(constants.PI_OVER_5.get());
    const basis_rotation = constants.PI_OVER_5.get() - std.math.atan2(corner_c.y(), corner_c.x());
    const scale = 2.0 * constants.DISTANCE_TO_EDGE / edge_midpoint_d;

    var points = [_]Face{ corner_a, corner_b, corner_c, corner_d, corner_e };
    const cos_angle = std.math.cos(basis_rotation);
    const sin_angle = std.math.sin(basis_rotation);
    for (&points) |*vertex| {
        const scaled_x = vertex.x() * scale;
        const scaled_y = vertex.y() * scale;
        vertex.* = Face.new(
            scaled_x * cos_angle - scaled_y * sin_angle,
            scaled_x * sin_angle + scaled_y * cos_angle,
        );
    }

    corner_a = points[0];
    corner_b = points[1];
    corner_c = points[2];
    corner_d = points[3];
    corner_e = points[4];

    const pentagon_shape = geometry.PentagonShape.new(.{ corner_a, corner_b, corner_c, corner_d, corner_e });
    const bisector_angle = std.math.atan2(corner_c.y(), corner_c.x()) - constants.PI_OVER_5.get();

    const triangle_u = Face.new(0.0, 0.0);
    const l = constants.DISTANCE_TO_EDGE / std.math.cos(constants.PI_OVER_5.get());
    const v_angle_value = bisector_angle + constants.PI_OVER_5.get();
    const w_angle = bisector_angle - constants.PI_OVER_5.get();
    const triangle_v = Face.new(l * std.math.cos(v_angle_value), l * std.math.sin(v_angle_value));
    const triangle_w = Face.new(l * std.math.cos(w_angle), l * std.math.sin(w_angle));

    const triangle_shape = geometry.PentagonShape.new_triangle(.{ triangle_u, triangle_v, triangle_w });
    const triangle_basis = Mat2.from_cols(triangle_v, triangle_w);
    const triangle_basis_inverse = triangle_basis.inverse().?;

    return .{
        .vertices = .{ .a = corner_a, .b = corner_b, .c = corner_c, .d = corner_d, .e = corner_e },
        .pentagon = pentagon_shape,
        .triangle_vertices = .{ .u = triangle_u, .v = triangle_v, .w = triangle_w, .v_angle = Radians.new_unchecked(v_angle_value) },
        .triangle = triangle_shape,
        .basis = triangle_basis,
        .basis_inverse = triangle_basis_inverse,
    };
}

var constants_cache: ?PentagonConstants = null;

fn get_constants() *const PentagonConstants {
    if (constants_cache == null) {
        constants_cache = make_constants();
    }
    return &constants_cache.?;
}

pub fn a() Face {
    return get_constants().vertices.a;
}

pub fn b() Face {
    return get_constants().vertices.b;
}

pub fn c() Face {
    return get_constants().vertices.c;
}

pub fn d() Face {
    return get_constants().vertices.d;
}

pub fn e() Face {
    return get_constants().vertices.e;
}

pub fn pentagon() geometry.PentagonShape {
    return get_constants().pentagon;
}

pub fn u() Face {
    return get_constants().triangle_vertices.u;
}

pub fn v() Face {
    return get_constants().triangle_vertices.v;
}

pub fn w() Face {
    return get_constants().triangle_vertices.w;
}

pub fn v_angle() Radians {
    return get_constants().triangle_vertices.v_angle;
}

pub fn triangle() geometry.PentagonShape {
    return get_constants().triangle;
}

pub fn basis() Mat2 {
    return get_constants().basis;
}

pub fn basis_inverse() Mat2 {
    return get_constants().basis_inverse;
}
