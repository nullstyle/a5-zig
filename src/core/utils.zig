const coordinate_systems = @import("coordinate_systems");
const hilbert = @import("hilbert.zig");

pub const OriginId = u8;
pub const Quat = [4]f64;

pub const Origin = struct {
    id: OriginId,
    axis: coordinate_systems.Spherical,
    quat: Quat,
    inverse_quat: Quat,
    angle: coordinate_systems.Radians,
    orientation: [5]hilbert.Orientation,
    first_quintant: usize,
};

pub const A5Cell = struct {
    origin_id: OriginId,
    segment: usize,
    s: u64,
    resolution: i32,
};
