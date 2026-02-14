const pentagon_mod = @import("pentagon.zig");
const spherical_polygon_mod = @import("spherical_polygon.zig");
const spherical_triangle_mod = @import("spherical_triangle.zig");

pub const track = "Geometry track";

pub const Pentagon = pentagon_mod.Pentagon;
pub const Triangle = pentagon_mod.Triangle;
pub const PentagonShape = pentagon_mod.PentagonShape;

pub const SphericalPolygon = spherical_polygon_mod.SphericalPolygon;
pub const SphericalPolygonShape = spherical_polygon_mod.SphericalPolygonShape;
pub const SphericalTriangleShape = spherical_triangle_mod.SphericalTriangleShape;

pub const pentagon = pentagon_mod;
pub const spherical_polygon = spherical_polygon_mod;
pub const spherical_triangle = spherical_triangle_mod;
