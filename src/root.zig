const std = @import("std");
const builtin = @import("builtin");

pub const coordinate_systems = @import("coordinate_systems");
pub const core = @import("core");
pub const geometry = @import("geometry");
pub const projections = @import("projections");
pub const utils = @import("utils");

pub const cell_to_boundary = core.cell_to_boundary;
pub const cell_to_lonlat = core.cell_to_lonlat;
pub const lonlat_to_cell = core.lonlat_to_cell;
pub const hex_to_u64 = core.hex_to_u64;
pub const u64_to_hex = core.u64_to_hex;
pub const cell_area = core.cell_area;
pub const get_num_cells = core.get_num_cells;
pub const get_resolution = core.get_resolution;
pub const cell_to_children = core.cell_to_children;
pub const cell_to_parent = core.cell_to_parent;
pub const get_res0_cells = core.get_res0_cells;
pub const compact = core.compact.compact;
pub const uncompact = core.compact.uncompact;
pub const CellToBoundaryOptions = core.CellToBoundaryOptions;
pub const Degrees = coordinate_systems.Degrees;
pub const LonLat = coordinate_systems.LonLat;
pub const Radians = coordinate_systems.Radians;
pub const A5Cell = core.A5Cell;

pub const module_map = .{
    .coordinate_systems = "coordinate_systems",
    .core = "core",
    .geometry = "geometry",
    .projections = "projections",
    .utils = "utils",
};

pub fn bufferedPrint() !void {
    if (builtin.os.tag == .freestanding) {
        return;
    }

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print("Run `zig build test` to run Track 0 infrastructure tests.\n", .{});
    try stdout.flush();
}
