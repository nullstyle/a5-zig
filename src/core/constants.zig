const std = @import("std");
const Radians = @import("coordinate_systems").Radians;

pub const PHI: f64 = 1.618033988749895;

pub const TWO_PI: Radians = Radians.new_unchecked(std.math.tau);

pub const TWO_PI_OVER_5: Radians = Radians.new_unchecked(std.math.tau / 5.0);

pub const PI_OVER_5: Radians = Radians.new_unchecked(std.math.pi / 5.0);

pub const PI_OVER_10: Radians = Radians.new_unchecked(std.math.pi / 10.0);

pub const DIHEDRAL_ANGLE: Radians = Radians.new_unchecked(2.0344439357957027);

pub const INTERHEDRAL_ANGLE: Radians = Radians.new_unchecked(1.1071487177940904);

pub const FACE_EDGE_ANGLE: Radians = Radians.new_unchecked(1.0172219678978514);

pub const DISTANCE_TO_EDGE: f64 = 0.6180339887498949;

pub const DISTANCE_TO_VERTEX: f64 = 0.7639320225002102;

pub const R_INSCRIBED: f64 = 1.0;

pub const R_MIDEDGE: f64 = 1.1755705045849463;

pub const R_CIRCUMSCRIBED: f64 = 1.2584085723648188;
