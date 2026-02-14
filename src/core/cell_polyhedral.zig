const std = @import("std");
const coordinate_systems = @import("coordinate_systems");
const geometry = @import("geometry");
const ct = @import("coordinate_transforms.zig");
const vector = @import("utils").vector;

const Barycentric = coordinate_systems.Barycentric;
const Cartesian = coordinate_systems.Cartesian;
const Face = coordinate_systems.Face;
const FaceTriangle = coordinate_systems.FaceTriangle;
const SphericalTriangle = coordinate_systems.SphericalTriangle;

const SphericalTriangleShape = geometry.spherical_triangle.SphericalTriangleShape;
const quadruple_product = vector.quadruple_product;
const slerp = vector.slerp;
const vector_difference = vector.vector_difference;

pub const PolyhedralProjection = struct {
    pub fn forward(
        _: PolyhedralProjection,
        v: Cartesian,
        spherical_triangle: SphericalTriangle,
        face_triangle: FaceTriangle,
    ) Face {
        const a = spherical_triangle.a;
        const b = spherical_triangle.b;
        const c = spherical_triangle.c;

        var triangle_shape = SphericalTriangleShape.new(&[_]Cartesian{ a, b, c }) catch unreachable;

        const z = normalize(subtract(v, a));
        const p = normalize(quadruple_product(a, z, b, c));

        const h = vector_difference(a, v) / vector_difference(a, p);
        const area_abc = triangle_shape.get_area().get();
        const scaled_area = h / area_abc;

        var area_apc_triangle = SphericalTriangleShape.new(&[_]Cartesian{ a, p, c }) catch unreachable;
        var area_abp_triangle = SphericalTriangleShape.new(&[_]Cartesian{ a, b, p }) catch unreachable;

        const b_coords = Barycentric.new(
            1.0 - h,
            scaled_area * area_apc_triangle.get_area().get(),
            scaled_area * area_abp_triangle.get_area().get(),
        );

        return ct.barycentric_to_face(b_coords, face_triangle);
    }

    pub fn inverse(
        self: PolyhedralProjection,
        face_point: Face,
        face_triangle: FaceTriangle,
        spherical_triangle: SphericalTriangle,
    ) Cartesian {
        const a = spherical_triangle.a;
        const b = spherical_triangle.b;
        const c = spherical_triangle.c;
        var triangle_shape = SphericalTriangleShape.new(&[_]Cartesian{ a, b, c }) catch unreachable;

        const b_coords = ct.face_to_barycentric(face_point, face_triangle);
        const threshold = 1.0 - 1e-14;
        if (b_coords.u > threshold) return a;
        if (b_coords.v > threshold) return b;
        if (b_coords.w > threshold) return c;

        const c1 = cross(b, c);
        const area_abc = triangle_shape.get_area().get();
        const h = 1.0 - b_coords.u;
        const r = b_coords.w / h;
        const alpha = r * area_abc;
        const s = std.math.sin(alpha);
        const half_c = std.math.sin(alpha / 2.0);
        const cc = 2.0 * half_c * half_c;

        const c01 = dot(a, b);
        const c12 = dot(b, c);
        const c20 = dot(c, a);
        const s12 = length(c1);

        const v = dot(a, c1);
        const f = s * v + cc * (c01 * c12 - c20);
        const g = cc * s12 * (1.0 + c01);
        const q = (2.0 / std.math.acos(c12)) * std.math.atan2(g, f);
        const p = slerp(b, c, q);
        const k = vector_difference(a, p);
        const t = self.safe_acos(h * k) / self.safe_acos(k);

        return slerp(a, p, t);
    }

    fn safe_acos(_: PolyhedralProjection, x: f64) f64 {
        if (x < 1e-3) {
            return 2.0 * x + (x * x * x) / 3.0;
        }

        return std.math.acos(1.0 - 2.0 * x * x);
    }
};

fn dot(a: Cartesian, b: Cartesian) f64 {
    return a.x() * b.x() + a.y() * b.y() + a.z() * b.z();
}

fn cross(a: Cartesian, b: Cartesian) Cartesian {
    return Cartesian.new(
        a.y() * b.z() - a.z() * b.y(),
        a.z() * b.x() - a.x() * b.z(),
        a.x() * b.y() - a.y() * b.x(),
    );
}

fn length(v: Cartesian) f64 {
    return std.math.sqrt(v.x() * v.x() + v.y() * v.y() + v.z() * v.z());
}

fn normalize(v: Cartesian) Cartesian {
    const len = length(v);
    if (len == 0.0) return v;
    return Cartesian.new(v.x() / len, v.y() / len, v.z() / len);
}

fn subtract(a: Cartesian, b: Cartesian) Cartesian {
    return Cartesian.new(a.x() - b.x(), a.y() - b.y(), a.z() - b.z());
}
