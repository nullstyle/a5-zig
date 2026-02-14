const std = @import("std");
const coordinate_systems = @import("coordinate_systems");
const Face = coordinate_systems.Face;

pub const Pentagon = [5]Face;
pub const Triangle = [3]Face;

const MAX_VERTICES: usize = 128;

/// A variable-size face polygon helper used for pentagon and helper triangle fixtures.
pub const PentagonShape = struct {
    vertices: [MAX_VERTICES]Face,
    len: usize,

    pub fn new(vertices: Pentagon) PentagonShape {
        return from_vertices(vertices[0..]);
    }

    pub fn new_triangle(vertices: Triangle) PentagonShape {
        return from_vertices(vertices[0..]);
    }

    fn from_vertices(vertices: []const Face) PentagonShape {
        if (vertices.len == 0) {
            return PentagonShape{
                .vertices = [_]Face{Face.new(0.0, 0.0)} ** MAX_VERTICES,
                .len = 0,
            };
        }
        if (vertices.len > MAX_VERTICES) {
            @panic("Too many vertices for PentagonShape");
        }

        var shape = PentagonShape{
            .vertices = [_]Face{Face.new(0.0, 0.0)} ** MAX_VERTICES,
            .len = vertices.len,
        };
        var i: usize = 0;
        while (i < vertices.len) : (i += 1) {
            shape.vertices[i] = vertices[i];
        }

        if (!shape.is_winding_correct()) {
            shape.reverse();
        }
        return shape;
    }

    pub fn clone(self: PentagonShape) PentagonShape {
        return self;
    }

    fn reverse(self: *PentagonShape) void {
        if (self.len <= 1) return;
        var i: usize = 0;
        var j: usize = self.len - 1;
        while (i < j) : ({
            i += 1;
            j -= 1;
        }) {
            std.mem.swap(Face, &self.vertices[i], &self.vertices[j]);
        }
    }

    pub fn set_vertices(self: *PentagonShape, vertices: []const Face) void {
        self.* = from_vertices(vertices);
    }

    fn from_vertices_inplace(self: *PentagonShape, vertices: []const Face) void {
        if (vertices.len > MAX_VERTICES) {
            @panic("Too many vertices for PentagonShape");
        }
        self.* = from_vertices(vertices);
    }

    pub fn get_area(self: PentagonShape) f64 {
        var signed_area: f64 = 0.0;
        if (self.len < 2) return signed_area;

        var i: usize = 0;
        while (i < self.len) : (i += 1) {
            const j = (i + 1) % self.len;
            const vx = self.vertices[j].x() - self.vertices[i].x();
            const vy = self.vertices[j].y() + self.vertices[i].y();
            signed_area += vx * vy;
        }

        return signed_area;
    }

    fn is_winding_correct(self: PentagonShape) bool {
        return self.get_area() >= 0.0;
    }

    pub fn get_vertices(self: PentagonShape) Pentagon {
        var result = [_]Face{Face.new(0.0, 0.0)} ** 5;
        const count = @min(5, self.len);
        var i: usize = 0;
        while (i < count) : (i += 1) {
            result[i] = self.vertices[i];
        }
        return result;
    }

    pub fn get_vertices_vec(self: *const PentagonShape) []const Face {
        return self.vertices[0..self.len];
    }

    pub fn scale(self: *PentagonShape, factor: f64) *PentagonShape {
        var i: usize = 0;
        while (i < self.len) : (i += 1) {
            const vertex = self.vertices[i];
            self.vertices[i] = Face.new(vertex.x() * factor, vertex.y() * factor);
        }
        return self;
    }

    /// Rotates the pentagon 180 degrees (negating x and y).
    pub fn rotate180(self: *PentagonShape) *PentagonShape {
        var i: usize = 0;
        while (i < self.len) : (i += 1) {
            const vertex = self.vertices[i];
            self.vertices[i] = Face.new(-vertex.x(), -vertex.y());
        }
        return self;
    }

    /// Mirrors across the x-axis and keeps winding orientation consistent.
    pub fn reflect_y(self: *PentagonShape) *PentagonShape {
        var i: usize = 0;
        while (i < self.len) : (i += 1) {
            const vertex = self.vertices[i];
            self.vertices[i] = Face.new(vertex.x(), -vertex.y());
        }
        self.reverse();
        return self;
    }

    pub fn translate(self: *PentagonShape, translation: Face) *PentagonShape {
        var i: usize = 0;
        while (i < self.len) : (i += 1) {
            const vertex = self.vertices[i];
            self.vertices[i] = Face.new(vertex.x() + translation.x(), vertex.y() + translation.y());
        }
        return self;
    }

    pub fn get_center(self: PentagonShape) Face {
        if (self.len == 0) {
            return Face.new(0.0, 0.0);
        }

        const n = @as(f64, @floatFromInt(self.len));
        var sum_x: f64 = 0.0;
        var sum_y: f64 = 0.0;
        for (self.get_vertices_vec()) |vertex| {
            sum_x += vertex.x() / n;
            sum_y += vertex.y() / n;
        }
        return Face.new(sum_x, sum_y);
    }

    /// Returns a positive value for inside points and negative values for outside points.
    /// The returned magnitude is proportional to shortest edge-crossing distance when outside.
    pub fn contains_point(self: PentagonShape, point: Face) f64 {
        if (!self.is_winding_correct()) {
            @panic("Pentagon is not counter-clockwise");
        }
        if (self.len == 0) return 1.0;

        var d_max: f64 = 1.0;
        var i: usize = 0;
        while (i < self.len) : (i += 1) {
            const j = (i + 1) % self.len;
            const v1 = self.vertices[i];
            const v2 = self.vertices[j];

            const dx = v1.x() - v2.x();
            const dy = v1.y() - v2.y();
            const px = point.x() - v1.x();
            const py = point.y() - v1.y();
            const cross_product = dx * py - dy * px;

            if (cross_product < 0.0) {
                const p_length = std.math.sqrt(px * px + py * py);
                if (p_length > 0.0) {
                    d_max = @min(d_max, cross_product / p_length);
                }
            }
        }
        return d_max;
    }

    /// Splits each edge into `segments` pieces (including original endpoints).
    /// Returns a new shape with inserted interpolation points.
    pub fn split_edges(self: PentagonShape, segments: usize) PentagonShape {
        if (segments <= 1) {
            return self.clone();
        }

        var output = [_]Face{Face.new(0.0, 0.0)} ** MAX_VERTICES;
        var output_len: usize = 0;
        const max_count = self.len * segments;
        if (max_count > MAX_VERTICES) {
            @panic("Too many split segments for fixed vertex buffer");
        }

        var i: usize = 0;
        while (i < self.len) : (i += 1) {
            const v1 = self.vertices[i];
            const v2 = self.vertices[(i + 1) % self.len];
            const base = output_len;

            output[base + 0] = v1;
            output_len += 1;

            var j: usize = 1;
            while (j < segments) : (j += 1) {
                const t = @as(f64, @floatFromInt(j)) / @as(f64, @floatFromInt(segments));
                output[base + j] = Face.new(
                    v1.x() + t * (v2.x() - v1.x()),
                    v1.y() + t * (v2.y() - v1.y()),
                );
                output_len += 1;
            }
        }

        return from_vertices(output[0..output_len]);
    }
};
