const std = @import("std");
const a5 = @import("a5");

const serialization = a5.core.serialization;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 2) {
        std.debug.print(
            "Usage: zig build export-cell-ids -- <resolution>\n",
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

    const ids = try serialization.cell_to_children(allocator, serialization.WORLD_CELL, target_resolution);
    defer allocator.free(ids);

    var stdout_buffer: [64 * 1024]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&stdout_buffer);
    const writer = &stdout.interface;

    for (ids) |id| {
        try writer.print("{x:0>16}\n", .{id});
    }
    try writer.flush();
}
