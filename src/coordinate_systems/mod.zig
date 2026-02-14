const base = @import("base.zig");
const coords = @import("coords.zig");
const lonlat = @import("lonlat.zig");
const polar = @import("polar.zig");
const spherical = @import("spherical.zig");

pub const track = "Track 1";

pub const Degrees = base.Degrees;
pub const Radians = base.Radians;

pub const Vec2 = @import("vec2.zig").Vec2;
pub const Vec3 = @import("vec3.zig").Vec3;
pub const vec2 = @import("vec2.zig");
pub const vec3 = @import("vec3.zig");

pub const Face = coords.Face;
pub const IJ = coords.IJ;
pub const KJ = coords.KJ;
pub const Cartesian = coords.Cartesian;
pub const Barycentric = coords.Barycentric;
pub const FaceTriangle = coords.FaceTriangle;
pub const SphericalTriangle = coords.SphericalTriangle;

pub const LonLat = lonlat.LonLat;
pub const Polar = polar.Polar;
pub const Spherical = spherical.Spherical;
