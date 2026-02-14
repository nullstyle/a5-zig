const std = @import("std");
const coordinate_systems = @import("coordinate_systems");
const constants = @import("constants.zig");
const origin = @import("origin.zig");

const Cartesian = coordinate_systems.Cartesian;
const Radians = coordinate_systems.Radians;
const Spherical = coordinate_systems.Spherical;

pub const CRS = struct {
    vertices: [62]Cartesian,
    len: usize,
    invocations: usize,

    pub const Error = error{
        VertexNotFound,
        InvalidVertexCount,
    };

    pub fn new() Error!CRS {
        return init();
    }

    pub fn init() Error!CRS {
        var crs = CRS{
            .vertices = undefined,
            .len = 0,
            .invocations = 0,
        };

        crs.add_face_centers();
        crs.add_vertices();
        crs.add_midpoints();

        if (crs.len != 62) {
            return Error.InvalidVertexCount;
        }

        return crs;
    }

    pub fn get_vertex(self: *CRS, point: Cartesian) Error!Cartesian {
        self.invocations += 1;
        if (self.invocations == 10000) {
            std.debug.print("Warning: Too many CRS invocations, results should be cached\n", .{});
        }

        for (self.vertices[0..self.len]) |vertex| {
            if (vec3_distance(point, vertex) < 1e-5) {
                return vertex;
            }
        }

        return Error.VertexNotFound;
    }

    fn add_face_centers(self: *CRS) void {
        const origins = origin.get_origins();
        for (origins) |face| {
            const cartesian = to_cartesian(face.axis);
            _ = self.add(cartesian);
        }
    }

    fn add_vertices(self: *CRS) void {
        const phi_vertex = std.math.atan(constants.DISTANCE_TO_VERTEX);

        const origins = origin.get_origins();
        for (origins) |face| {
            var i: usize = 0;
            while (i < 5) : (i += 1) {
                const theta_vertex = ((2.0 * @as(f64, @floatFromInt(i)) + 1.0) * std.math.pi) / 5.0;
                const spherical = Spherical.new(
                    Radians.new_unchecked(theta_vertex + face.angle.get()),
                    Radians.new_unchecked(phi_vertex),
                );
                const transformed = transform_quat(to_cartesian(spherical), face.quat);
                _ = self.add(transformed);
            }
        }
    }

    fn add_midpoints(self: *CRS) void {
        const phi_midpoint = std.math.atan(constants.DISTANCE_TO_EDGE);

        const origins = origin.get_origins();
        for (origins) |face| {
            var i: usize = 0;
            while (i < 5) : (i += 1) {
                const theta_midpoint = (2.0 * @as(f64, @floatFromInt(i)) * std.math.pi) / 5.0;
                const spherical = Spherical.new(
                    Radians.new_unchecked(theta_midpoint + face.angle.get()),
                    Radians.new_unchecked(phi_midpoint),
                );
                const transformed = transform_quat(to_cartesian(spherical), face.quat);
                _ = self.add(transformed);
            }
        }
    }

    fn add(self: *CRS, new_vertex: Cartesian) bool {
        const normalized = normalize(new_vertex);
        var i: usize = 0;
        while (i < self.len) : (i += 1) {
            if (vec3_distance(normalized, self.vertices[i]) < 1e-5) {
                return false;
            }
        }

        self.vertices[self.len] = normalized;
        self.len += 1;
        return true;
    }
};

fn to_cartesian(spherical: Spherical) Cartesian {
    const theta = spherical.theta();
    const phi = spherical.phi();
    const sin_phi = std.math.sin(phi.get());
    return Cartesian.new(
        sin_phi * std.math.cos(theta.get()),
        sin_phi * std.math.sin(theta.get()),
        std.math.cos(phi.get()),
    );
}

fn normalize(v: Cartesian) Cartesian {
    const len = vec3_length(v);
    if (len == 0.0) {
        return v;
    }
    return Cartesian.new(
        v.x() / len,
        v.y() / len,
        v.z() / len,
    );
}

fn vec3_length(v: Cartesian) f64 {
    return std.math.sqrt(v.x() * v.x() + v.y() * v.y() + v.z() * v.z());
}

fn vec3_distance(a: Cartesian, b: Cartesian) f64 {
    const dx = a.x() - b.x();
    const dy = a.y() - b.y();
    const dz = a.z() - b.z();
    return std.math.sqrt(dx * dx + dy * dy + dz * dz);
}

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
