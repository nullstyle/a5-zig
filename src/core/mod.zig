pub const track = "Core track";

pub const constants = @import("constants.zig");
pub const authalic = @import("authalic.zig");
pub const hex = @import("hex.zig");
pub const coordinate_transforms = @import("coordinate_transforms.zig");
pub const dodecahedron_quaternions = @import("dodecahedron_quaternions.zig");
pub const pentagon = @import("pentagon.zig");
pub const tiling = @import("tiling.zig");
pub const hilbert = @import("hilbert.zig");
pub const serialization = @import("serialization.zig");
pub const cell_info = @import("cell_info.zig");
pub const origin = @import("origin.zig");
pub const cell = @import("cell.zig");
pub const compact = @import("compact.zig");
pub const utils = @import("utils.zig");

pub const PHI = constants.PHI;
pub const TWO_PI = constants.TWO_PI;
pub const TWO_PI_OVER_5 = constants.TWO_PI_OVER_5;
pub const PI_OVER_5 = constants.PI_OVER_5;
pub const PI_OVER_10 = constants.PI_OVER_10;
pub const DIHEDRAL_ANGLE = constants.DIHEDRAL_ANGLE;
pub const INTERHEDRAL_ANGLE = constants.INTERHEDRAL_ANGLE;
pub const FACE_EDGE_ANGLE = constants.FACE_EDGE_ANGLE;
pub const DISTANCE_TO_EDGE = constants.DISTANCE_TO_EDGE;
pub const DISTANCE_TO_VERTEX = constants.DISTANCE_TO_VERTEX;
pub const R_INSCRIBED = constants.R_INSCRIBED;
pub const R_MIDEDGE = constants.R_MIDEDGE;
pub const R_CIRCUMSCRIBED = constants.R_CIRCUMSCRIBED;

pub const hex_to_u64 = hex.hex_to_u64;
pub const u64_to_hex = hex.u64_to_hex;

pub const Orientation = hilbert.Orientation;
pub const Quaternary = hilbert.Quaternary;
pub const Flip = hilbert.Flip;
pub const Anchor = hilbert.Anchor;
pub const YES = hilbert.YES;
pub const NO = hilbert.NO;

pub const ij_to_kj = hilbert.ij_to_kj;
pub const kj_to_ij = hilbert.kj_to_ij;
pub const quaternary_to_kj = hilbert.quaternary_to_kj;
pub const quaternary_to_flips = hilbert.quaternary_to_flips;
pub const s_to_anchor = hilbert.s_to_anchor;
pub const ij_to_s = hilbert.ij_to_s;
pub const get_required_digits = hilbert.get_required_digits;

pub const A5Cell = utils.A5Cell;
pub const Origin = utils.Origin;
pub const OriginId = utils.OriginId;

pub const FIRST_HILBERT_RESOLUTION = serialization.FIRST_HILBERT_RESOLUTION;
pub const MAX_RESOLUTION = serialization.MAX_RESOLUTION;
pub const HILBERT_START_BIT = serialization.HILBERT_START_BIT;
pub const REMOVAL_MASK = serialization.REMOVAL_MASK;
pub const ORIGIN_SEGMENT_MASK = serialization.ORIGIN_SEGMENT_MASK;
pub const ALL_ONES = serialization.ALL_ONES;
pub const WORLD_CELL = serialization.WORLD_CELL;

pub const deserialize = serialization.deserialize;
pub const serialize = serialization.serialize;
pub const get_resolution = serialization.get_resolution;
pub const cell_to_children = serialization.cell_to_children;
pub const cell_to_parent = serialization.cell_to_parent;
pub const get_res0_cells = serialization.get_res0_cells;
pub const is_first_child = serialization.is_first_child;
pub const get_stride = serialization.get_stride;

pub const get_num_cells = cell_info.get_num_cells;
pub const get_num_children = cell_info.get_num_children;
pub const cell_area = cell_info.cell_area;

pub const CellToBoundaryOptions = cell.CellToBoundaryOptions;
pub const lonlat_to_cell = cell.lonlat_to_cell;
pub const cell_to_lonlat = cell.cell_to_lonlat;
pub const cell_to_boundary = cell.cell_to_boundary;
pub const a5cell_contains_point = cell.a5cell_contains_point;
