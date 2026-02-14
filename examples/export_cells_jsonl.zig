const std = @import("std");
const a5 = @import("a5");

const LonLat = a5.coordinate_systems.LonLat;
const cell = a5.core.cell;
const serialization = a5.core.serialization;

fn writePolygonJson(writer: anytype, polygon: []const LonLat) !void {
    try writer.writeAll("[");
    for (polygon, 0..) |vertex, idx| {
        if (idx != 0) try writer.writeAll(",");
        try writer.print("[{d:.12},{d:.12}]", .{
            vertex.longitude(),
            vertex.latitude(),
        });
    }
    try writer.writeAll("]");
}

fn writeCellJsonl(
    allocator: std.mem.Allocator,
    writer: anytype,
    cell_id: u64,
    resolution: i32,
    segments: ?i32,
) !void {
    const boundary = try cell.cell_to_boundary(allocator, cell_id, .{
        .closed_ring = true,
        .segments = segments,
    });
    defer allocator.free(boundary);

    try writer.print(
        "{{\"cell\":\"{x:0>16}\",\"cell_u64\":{},\"resolution\":{},\"polygon\":",
        .{ cell_id, cell_id, resolution },
    );
    try writePolygonJson(writer, boundary);
    try writer.writeAll("}\n");
}

fn emitCellsAtResolution(
    allocator: std.mem.Allocator,
    writer: anytype,
    cell_id: u64,
    current_resolution: i32,
    target_resolution: i32,
    segments: ?i32,
    written_count: *u64,
) !void {
    if (current_resolution == target_resolution) {
        try writeCellJsonl(allocator, writer, cell_id, target_resolution, segments);
        written_count.* += 1;
        return;
    }

    const next_resolution = current_resolution + 1;
    const children = try serialization.cell_to_children(allocator, cell_id, next_resolution);
    defer allocator.free(children);

    for (children) |child_id| {
        try emitCellsAtResolution(
            allocator,
            writer,
            child_id,
            next_resolution,
            target_resolution,
            segments,
            written_count,
        );
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 2 and args.len != 3) {
        std.debug.print(
            "Usage: zig build export-cells-jsonl -- <resolution> [segments]\n",
            .{},
        );
        return;
    }

    const target_resolution = std.fmt.parseInt(i32, args[1], 10) catch {
        std.debug.print("Invalid resolution: {s}\n", .{args[1]});
        return;
    };

    if (target_resolution < -1 or target_resolution > serialization.MAX_RESOLUTION) {
        std.debug.print(
            "Resolution must be in [-1, {}], got {}\n",
            .{ serialization.MAX_RESOLUTION, target_resolution },
        );
        return;
    }

    var segments: ?i32 = null;
    if (args.len == 3) {
        const parsed_segments = std.fmt.parseInt(i32, args[2], 10) catch {
            std.debug.print("Invalid segments value: {s}\n", .{args[2]});
            return;
        };
        if (parsed_segments < 1) {
            std.debug.print("segments must be >= 1, got {}\n", .{parsed_segments});
            return;
        }
        segments = parsed_segments;
    }

    var output_buffer: [64 * 1024]u8 = undefined;
    var output_writer = std.fs.File.stdout().writer(&output_buffer);
    const writer = &output_writer.interface;

    var written_count: u64 = 0;
    try emitCellsAtResolution(
        allocator,
        writer,
        serialization.WORLD_CELL,
        -1,
        target_resolution,
        segments,
        &written_count,
    );
    try writer.flush();

    std.debug.print(
        "Wrote {} cells at resolution {} to stdout\n",
        .{ written_count, target_resolution },
    );
}
