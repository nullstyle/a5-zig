const std = @import("std");
const coordinate_systems = @import("coordinate_systems");
const ct = @import("coordinate_transforms.zig");
const constants = @import("constants.zig");
const core_origin = @import("origin.zig");
const core_tiling = @import("tiling.zig");

const CRS = @import("cell_crs.zig").CRS;
const GnomonicProjection = @import("cell_gnomonic.zig").GnomonicProjection;
const PolyhedralProjection = @import("cell_polyhedral.zig").PolyhedralProjection;

const Cartesian = coordinate_systems.Cartesian;
const Face = coordinate_systems.Face;
const FaceTriangle = coordinate_systems.FaceTriangle;
const Polar = coordinate_systems.Polar;
const Radians = coordinate_systems.Radians;
const Spherical = coordinate_systems.Spherical;
const SphericalTriangle = coordinate_systems.SphericalTriangle;
const OriginId = @import("utils.zig").OriginId;

pub const FaceTriangleIndex = usize;

threadlocal var thread_projection: ?DodecahedronProjection = null;

pub const DodecahedronProjection = struct {
    face_triangles: [30]?FaceTriangle,
    spherical_triangles: [240]?SphericalTriangle,
    polyhedral: PolyhedralProjection,
    gnomonic: GnomonicProjection,
    crs: CRS,

    pub const Error = CRS.Error || error{
        InvalidOriginId,
        FaceTriangleIndexOutOfRange,
        FaceTriangleCacheOutOfRange,
        SphericalTriangleCacheOutOfRange,
    };

    pub fn new() Error!DodecahedronProjection {
        return .{
            .face_triangles = [_]?FaceTriangle{null} ** 30,
            .spherical_triangles = [_]?SphericalTriangle{null} ** 240,
            .polyhedral = .{},
            .gnomonic = .{},
            .crs = try CRS.new(),
        };
    }

    pub fn get_thread_local() Error!*DodecahedronProjection {
        if (thread_projection == null) {
            thread_projection = try DodecahedronProjection.new();
        }
        return &thread_projection.?;
    }

    pub fn forward(self: *DodecahedronProjection, spherical: Spherical, origin_id: OriginId) Error!Face {
        const origins = core_origin.get_origins();
        if (@as(usize, origin_id) >= origins.len) {
            return Error.InvalidOriginId;
        }
        const origin = origins[origin_id];

        const unprojected = ct.to_cartesian(spherical);
        const out = transform_quat(unprojected, origin.inverse_quat);

        const projected_spherical = ct.to_spherical(out);
        const polar = self.gnomonic.forward(projected_spherical);

        const rotated_polar = Polar.new(
            polar.rho(),
            Radians.new_unchecked(polar.gamma().get() - origin.angle.get()),
        );

        const face_triangle_index = self.get_face_triangle_index(rotated_polar);
        const reflect = self.should_reflect(rotated_polar);
        const face_triangle = try self.get_face_triangle(face_triangle_index, reflect, false);
        const spherical_triangle = try self.get_spherical_triangle(face_triangle_index, origin_id, reflect);

        return self.polyhedral.forward(unprojected, spherical_triangle, face_triangle);
    }

    pub fn inverse(self: *DodecahedronProjection, face: Face, origin_id: OriginId) Error!Spherical {
        const origins = core_origin.get_origins();
        if (@as(usize, origin_id) >= origins.len) {
            return Error.InvalidOriginId;
        }

        const polar = ct.to_polar(face);
        const face_triangle_index = self.get_face_triangle_index(polar);
        const reflect = self.should_reflect(polar);
        const face_triangle = try self.get_face_triangle(face_triangle_index, reflect, false);
        const spherical_triangle = try self.get_spherical_triangle(face_triangle_index, origin_id, reflect);
        const unprojected = self.polyhedral.inverse(face, face_triangle, spherical_triangle);
        return ct.to_spherical(unprojected);
    }

    fn should_reflect(self: DodecahedronProjection, polar: Polar) bool {
        const normalized_gamma = self.normalize_gamma(polar.gamma());
        const test_polar = Polar.new(polar.rho(), normalized_gamma);
        const d = ct.to_face(test_polar).x();
        return d > constants.DISTANCE_TO_EDGE;
    }

    fn get_face_triangle_index(_: DodecahedronProjection, polar: Polar) FaceTriangleIndex {
        const gamma = polar.gamma().get();
        const floor_segment = @as(i64, @intFromFloat(std.math.floor(gamma / constants.PI_OVER_5.get())));
        const index = @mod(floor_segment + 10, 10);
        return @intCast(index);
    }

    fn get_face_triangle(
        self: *DodecahedronProjection,
        face_triangle_index: FaceTriangleIndex,
        reflected: bool,
        squashed: bool,
    ) Error!FaceTriangle {
        if (face_triangle_index > 9) {
            return Error.FaceTriangleIndexOutOfRange;
        }

        var cache_index = face_triangle_index;
        if (reflected) {
            cache_index += if (squashed) 20 else 10;
        }

        if (cache_index >= self.face_triangles.len) {
            return Error.FaceTriangleCacheOutOfRange;
        }

        if (self.face_triangles[cache_index]) |cached| {
            return cached;
        }

        const face_triangle = if (reflected)
            try self.get_reflected_face_triangle(face_triangle_index, squashed)
        else
            try self.get_base_face_triangle(face_triangle_index);

        self.face_triangles[cache_index] = face_triangle;
        return face_triangle;
    }

    fn get_base_face_triangle(
        _: *DodecahedronProjection,
        face_triangle_index: FaceTriangleIndex,
    ) Error!FaceTriangle {
        const quintant = @mod(@divFloor(face_triangle_index + 1, 2), 5);
        const vertices = core_tiling.get_quintant_vertices(quintant).get_vertices();
        const v_center = vertices[0];
        const v_corner1 = vertices[1];
        const v_corner2 = vertices[2];

        const v_edge_midpoint = Face.new(
            (v_corner1.x() + v_corner2.x()) / 2.0,
            (v_corner1.y() + v_corner2.y()) / 2.0,
        );

        const even = face_triangle_index % 2 == 0;
        return if (even)
            FaceTriangle.new(v_center, v_edge_midpoint, v_corner1)
        else
            FaceTriangle.new(v_center, v_corner2, v_edge_midpoint);
    }

    fn get_reflected_face_triangle(
        self: *DodecahedronProjection,
        face_triangle_index: FaceTriangleIndex,
        squashed: bool,
    ) Error!FaceTriangle {
        const base = try self.get_base_face_triangle(face_triangle_index);

        var a = Face.new(-base.a.x(), -base.a.y());
        const b = base.b;
        const c = base.c;
        const even = face_triangle_index % 2 == 0;
        const midpoint = if (even) b else c;

        const scale = if (squashed) 1.0 + 1.0 / std.math.cos(constants.INTERHEDRAL_ANGLE.get()) else 2.0;
        a = Face.new(a.x() + midpoint.x() * scale, a.y() + midpoint.y() * scale);

        return FaceTriangle.new(a, c, b);
    }

    fn get_spherical_triangle(
        self: *DodecahedronProjection,
        face_triangle_index: FaceTriangleIndex,
        origin_id: OriginId,
        reflected: bool,
    ) Error!SphericalTriangle {
        var cache_index = 10 * @as(usize, origin_id) + face_triangle_index;
        if (reflected) {
            cache_index += 120;
        }

        if (cache_index >= self.spherical_triangles.len) {
            return Error.SphericalTriangleCacheOutOfRange;
        }

        if (self.spherical_triangles[cache_index]) |cached| {
            return cached;
        }

        const spherical_triangle = try self.compute_spherical_triangle(face_triangle_index, origin_id, reflected);
        self.spherical_triangles[cache_index] = spherical_triangle;
        return spherical_triangle;
    }

    fn compute_spherical_triangle(
        self: *DodecahedronProjection,
        face_triangle_index: FaceTriangleIndex,
        origin_id: OriginId,
        reflected: bool,
    ) Error!SphericalTriangle {
        const origins = core_origin.get_origins();
        if (@as(usize, origin_id) >= origins.len) {
            return Error.InvalidOriginId;
        }
        const origin = origins[origin_id];

        const face_triangle = try self.get_face_triangle(face_triangle_index, reflected, true);
        const faces = [_]Face{ face_triangle.a, face_triangle.b, face_triangle.c };
        var spherical_vertices: [3]Cartesian = undefined;

        for (faces, 0..) |face, i| {
            const polar = ct.to_polar(face);
            const rotated_polar = Polar.new(
                polar.rho(),
                Radians.new_unchecked(polar.gamma().get() + origin.angle.get()),
            );
            const rotated = ct.to_cartesian(self.gnomonic.inverse(rotated_polar));
            const transformed = transform_quat(rotated, origin.quat);
            spherical_vertices[i] = try self.crs.get_vertex(transformed);
        }

        return SphericalTriangle.new(
            spherical_vertices[0],
            spherical_vertices[1],
            spherical_vertices[2],
        );
    }

    fn normalize_gamma(_: DodecahedronProjection, gamma: Radians) Radians {
        const segment = gamma.get() / constants.TWO_PI_OVER_5.get();
        const s_center = std.math.round(segment);
        const s_offset = segment - s_center;
        const beta = s_offset * constants.TWO_PI_OVER_5.get();
        return Radians.new_unchecked(beta);
    }
};

fn transform_quat(v: Cartesian, q: [4]f64) Cartesian {
    const qx = q[0];
    const qy = q[1];
    const qz = q[2];
    const qw = q[3];

    const vx = v.x();
    const vy = v.y();
    const vz = v.z();

    const t1_x = (qw * vx) + (qy * vz) - (qz * vy);
    const t1_y = (qw * vy) + (qz * vx) - (qx * vz);
    const t1_z = (qw * vz) + (qx * vy) - (qy * vx);
    const t1_w = -qx * vx - qy * vy - qz * vz;

    const result_x = (t1_w * -qx) + (t1_x * qw) + (t1_y * -qz) - (t1_z * -qy);
    const result_y = (t1_w * -qy) + (t1_y * qw) + (t1_z * -qx) - (t1_x * -qz);
    const result_z = (t1_w * -qz) + (t1_z * qw) + (t1_x * -qy) - (t1_y * -qx);

    return Cartesian.new(result_x, result_y, result_z);
}
