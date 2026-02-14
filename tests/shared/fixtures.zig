const std = @import("std");

/// Shared JSON fixture loader for Track 0 and downstream tracks.
/// Fixtures are stored under `tests/fixtures` at the repository root.
/// File lookups are relative to this `tests/shared` source directory.
const fixture_base_path = "fixtures/";

pub fn fixtureText(comptime fixture_name: []const u8) []const u8 {
    return @embedFile(fixture_base_path ++ fixture_name);
}

pub fn parseFixture(
    comptime T: type,
    comptime fixture_name: []const u8,
    allocator: std.mem.Allocator,
) !std.json.Parsed(T) {
    return try std.json.parseFromSlice(
        T,
        allocator,
        fixtureText(fixture_name),
        .{ .ignore_unknown_fields = true },
    );
}

pub fn parseFixtureLeaky(
    comptime T: type,
    comptime fixture_name: []const u8,
    allocator: std.mem.Allocator,
) !T {
    return try std.json.parseFromSliceLeaky(
        T,
        allocator,
        fixtureText(fixture_name),
        .{ .ignore_unknown_fields = true },
    );
}
