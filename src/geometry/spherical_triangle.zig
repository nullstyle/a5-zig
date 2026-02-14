const std = @import("std");
const coordinate_systems = @import("coordinate_systems");
const spherical_polygon = @import("spherical_polygon.zig");
const SphericalPolygonShape = spherical_polygon.SphericalPolygonShape;
const Radians = coordinate_systems.Radians;
const Cartesian = coordinate_systems.Cartesian;

pub const SphericalTriangleShape = struct {
    inner: SphericalPolygonShape,

    pub const Error = error{
        InvalidVertexCount,
    };

    pub fn new(vertices: []const Cartesian) Error!SphericalTriangleShape {
        if (vertices.len != 3) {
            return Error.InvalidVertexCount;
        }
        return .{ .inner = SphericalPolygonShape.new(vertices) };
    }

    pub fn get_boundary(self: SphericalTriangleShape, allocator: std.mem.Allocator, n_segments: usize, closed_ring: bool) ![]Cartesian {
        return self.inner.get_boundary(allocator, n_segments, closed_ring);
    }

    pub fn slerp(self: SphericalTriangleShape, t: f64) Cartesian {
        return self.inner.slerp(t);
    }

    pub fn get_transformed_vertices(self: SphericalTriangleShape, t: f64) struct { Cartesian, Cartesian, Cartesian } {
        return self.inner.get_transformed_vertices(t);
    }

    pub fn contains_point(self: SphericalTriangleShape, point: Cartesian) f64 {
        return self.inner.contains_point(point);
    }

    pub fn get_area(self: *SphericalTriangleShape) Radians {
        return self.inner.get_area();
    }
};
