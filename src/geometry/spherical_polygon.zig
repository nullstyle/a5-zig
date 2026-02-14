const std = @import("std");
const coordinate_systems = @import("coordinate_systems");
const utils = @import("utils");

const Cartesian = coordinate_systems.Cartesian;
const Radians = coordinate_systems.Radians;

pub const SphericalPolygon = []Cartesian;

pub const SphericalPolygonShape = struct {
    vertices: []const Cartesian,
    area: ?Radians,

    pub fn new(vertices: []const Cartesian) SphericalPolygonShape {
        return .{
            .vertices = vertices,
            .area = null,
        };
    }

    /// Returns a closed boundary with `n_segments` interpolation points per edge.
    pub fn get_boundary(self: SphericalPolygonShape, allocator: std.mem.Allocator, n_segments: usize, closed_ring: bool) ![]Cartesian {
        if (self.vertices.len == 0 or n_segments == 0) {
            return try allocator.dupe(Cartesian, &[_]Cartesian{});
        }

        const base_len = self.vertices.len * n_segments;
        var len = base_len;
        if (closed_ring) len += 1;
        var points = try allocator.alloc(Cartesian, len);
        var count: usize = 0;

        var i: usize = 0;
        while (i < self.vertices.len * n_segments) : (i += 1) {
            const t = @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(n_segments));
            points[count] = self.slerp(t);
            count += 1;
        }

        if (closed_ring and count > 0) {
            points[count] = points[0];
            count += 1;
        }

        return points[0..count];
    }

    /// Linear interpolation across the polygon boundary. `t=1.5` interpolates edge 1→2.
    pub fn slerp(self: SphericalPolygonShape, t: f64) Cartesian {
        if (self.vertices.len == 0) {
            return Cartesian.new(0.0, 0.0, 0.0);
        }

        const n = self.vertices.len;
        const n_as_float = @as(f64, @floatFromInt(n));
        const t_wrapped = @mod(t, n_as_float);
        const f = t_wrapped - @floor(t_wrapped);

        var i = @as(usize, @intFromFloat(@floor(t_wrapped)));
        i = i % n;
        const j = (i + 1) % n;

        return utils.slerp(self.vertices[i], self.vertices[j], f);
    }

    /// Returns a vertex and vectors to neighboring edges.
    pub fn get_transformed_vertices(self: SphericalPolygonShape, t: f64) struct { Cartesian, Cartesian, Cartesian } {
        if (self.vertices.len == 0) {
            const zero = Cartesian.new(0.0, 0.0, 0.0);
            return .{ zero, zero, zero };
        }

        const n = self.vertices.len;
        const n_as_float = @as(f64, @floatFromInt(n));
        const i = @as(usize, @intFromFloat(@floor(@mod(t, n_as_float))));
        const j = (i + 1) % n;
        const k = (i + n - 1) % n;

        const v = self.vertices[i];
        const va = subtract(self.vertices[j], v);
        const vb = subtract(self.vertices[k], v);
        return .{ v, va, vb };
    }

    pub fn contains_point(self: SphericalPolygonShape, point: Cartesian) f64 {
        const n = self.vertices.len;
        var theta_delta_min = std.math.inf(f64);

        var i: usize = 0;
        while (i < n) : (i += 1) {
            const transformed = self.get_transformed_vertices(@as(f64, @floatFromInt(i)));
            const v = transformed.@"0";
            const va = transformed.@"1";
            const vb = transformed.@"2";

            const vp = subtract(point, v);
            const vp_n = normalize(vp);
            const va_n = normalize(va);
            const vb_n = normalize(vb);

            const cross_ap = cross(va_n, vp_n);
            const cross_pb = cross(vp_n, vb_n);
            const sin_ap = dot(v, cross_ap);
            const sin_pb = dot(v, cross_pb);
            theta_delta_min = @min(theta_delta_min, @min(sin_ap, sin_pb));
        }

        return theta_delta_min;
    }

    /// Calculate the area of the spherical polygon, with memoization.
    pub fn get_area(self: *SphericalPolygonShape) Radians {
        if (self.area) |cached| return cached;
        const computed = self.compute_area();
        self.area = computed;
        return computed;
    }

    fn compute_area(self: SphericalPolygonShape) Radians {
        if (self.vertices.len < 3) {
            return Radians.new_unchecked(0.0);
        }
        if (self.vertices.len == 3) {
            return self.get_triangle_area(self.vertices[0], self.vertices[1], self.vertices[2]);
        }

        var center = Cartesian.new(0.0, 0.0, 0.0);
        for (self.vertices) |vertex| {
            center = add(center, vertex);
        }
        center = normalize(center);

        var area: f64 = 0.0;
        var i: usize = 0;
        while (i < self.vertices.len) : (i += 1) {
            const v1 = self.vertices[i];
            const v2 = self.vertices[(i + 1) % self.vertices.len];
            const triangle = self.get_triangle_area(center, v1, v2);
            const triangle_area = triangle.get();
            if (!std.math.isNan(triangle_area)) {
                area += triangle_area;
            }
        }

        return Radians.new_unchecked(area);
    }

    /// Calculate area of a spherical triangle from three points.
    fn get_triangle_area(self: SphericalPolygonShape, v1: Cartesian, v2: Cartesian, v3: Cartesian) Radians {
        _ = self;
        const mid_a = normalize(lerp(v2, v3, 0.5));
        const mid_b = normalize(lerp(v3, v1, 0.5));
        const mid_c = normalize(lerp(v1, v2, 0.5));
        const s = utils.triple_product(mid_a, mid_b, mid_c);
        const clamped = std.math.clamp(s, -1.0, 1.0);

        const area = if (@abs(clamped) < 1e-8)
            2.0 * clamped
        else
            std.math.asin(clamped) * 2.0;

        return Radians.new_unchecked(area);
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

fn lerp(a: Cartesian, b: Cartesian, t: f64) Cartesian {
    return Cartesian.new(
        a.x() + t * (b.x() - a.x()),
        a.y() + t * (b.y() - a.y()),
        a.z() + t * (b.z() - a.z()),
    );
}

fn subtract(a: Cartesian, b: Cartesian) Cartesian {
    return Cartesian.new(a.x() - b.x(), a.y() - b.y(), a.z() - b.z());
}

fn add(a: Cartesian, b: Cartesian) Cartesian {
    return Cartesian.new(a.x() + b.x(), a.y() + b.y(), a.z() + b.z());
}
