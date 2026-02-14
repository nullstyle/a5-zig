pub const track = "Projections track";

pub const authalic = @import("authalic.zig");
pub const gnomonic = @import("gnomonic.zig");
pub const polyhedral = @import("polyhedral.zig");
pub const dodecahedron = @import("dodecahedron.zig");
pub const crs = @import("crs.zig");

pub const AuthalicProjection = authalic.AuthalicProjection;
pub const GnomonicProjection = gnomonic.GnomonicProjection;
pub const PolyhedralProjection = polyhedral.PolyhedralProjection;
pub const DodecahedronProjection = dodecahedron.DodecahedronProjection;
pub const CRS = crs.CRS;
