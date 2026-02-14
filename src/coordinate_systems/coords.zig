const std = @import("std");
const Vec2 = @import("vec2.zig").Vec2;
const Vec3 = @import("vec3.zig").Vec3;

pub const Face = struct {
    vec: Vec2,

    pub fn new(x_value: f64, y_value: f64) Face {
        return .{ .vec = .{ .x = x_value, .y = y_value } };
    }

    pub fn x(self: Face) f64 {
        return self.vec.x;
    }

    pub fn y(self: Face) f64 {
        return self.vec.y;
    }

    pub fn fromArray(arr: [2]f64) Face {
        return .{ .vec = Vec2.new(arr[0], arr[1]) };
    }

    pub fn toArray(self: Face) [2]f64 {
        return .{ self.x(), self.y() };
    }
};

pub const IJ = struct {
    vec: Vec2,

    pub fn new(x_value: f64, y_value: f64) IJ {
        return .{ .vec = .{ .x = x_value, .y = y_value } };
    }

    pub fn x(self: IJ) f64 {
        return self.vec.x;
    }

    pub fn y(self: IJ) f64 {
        return self.vec.y;
    }
};

pub const KJ = struct {
    vec: Vec2,

    pub fn new(x_value: f64, y_value: f64) KJ {
        return .{ .vec = .{ .x = x_value, .y = y_value } };
    }

    pub fn x(self: KJ) f64 {
        return self.vec.x;
    }

    pub fn y(self: KJ) f64 {
        return self.vec.y;
    }
};

pub const Cartesian = struct {
    vec: Vec3,

    pub fn new(x_value: f64, y_value: f64, z_value: f64) Cartesian {
        return .{ .vec = .{ .x = x_value, .y = y_value, .z = z_value } };
    }

    pub fn x(self: Cartesian) f64 {
        return self.vec.x;
    }

    pub fn y(self: Cartesian) f64 {
        return self.vec.y;
    }

    pub fn z(self: Cartesian) f64 {
        return self.vec.z;
    }

    pub fn fromArray(arr: [3]f64) Cartesian {
        return .{ .vec = Vec3.new(arr[0], arr[1], arr[2]) };
    }

    pub fn toArray(self: Cartesian) [3]f64 {
        return .{ self.x(), self.y(), self.z() };
    }
};

pub const Barycentric = struct {
    u: f64,
    v: f64,
    w: f64,

    pub fn new(u: f64, v: f64, w: f64) Barycentric {
        return .{ .u = u, .v = v, .w = w };
    }

    pub fn is_valid(self: Barycentric) bool {
        return @abs(self.u + self.v + self.w - 1.0) < 1e-12;
    }

    pub fn is_inside_triangle(self: Barycentric) bool {
        return self.u >= 0.0 and self.v >= 0.0 and self.w >= 0.0;
    }

    pub fn fromArray(arr: [3]f64) Barycentric {
        return .{ .u = arr[0], .v = arr[1], .w = arr[2] };
    }

    pub fn toArray(self: Barycentric) [3]f64 {
        return .{ self.u, self.v, self.w };
    }
};

pub const FaceTriangle = struct {
    a: Face,
    b: Face,
    c: Face,

    pub fn new(a: Face, b: Face, c: Face) FaceTriangle {
        return .{ .a = a, .b = b, .c = c };
    }

    pub fn fromArray(arr: [3]Face) FaceTriangle {
        return .{ .a = arr[0], .b = arr[1], .c = arr[2] };
    }

    pub fn fromFloatArray(arr: [3][2]f64) FaceTriangle {
        return .{
            .a = Face.fromArray(arr[0]),
            .b = Face.fromArray(arr[1]),
            .c = Face.fromArray(arr[2]),
        };
    }
};

pub const SphericalTriangle = struct {
    a: Cartesian,
    b: Cartesian,
    c: Cartesian,

    pub fn new(a: Cartesian, b: Cartesian, c: Cartesian) SphericalTriangle {
        return .{ .a = a, .b = b, .c = c };
    }

    pub fn fromArray(arr: [3]Cartesian) SphericalTriangle {
        return .{ .a = arr[0], .b = arr[1], .c = arr[2] };
    }
};
