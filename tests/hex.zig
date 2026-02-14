const std = @import("std");
const a5 = @import("a5");
const core = a5.core;

test "hex conversion" {
    const hex = "1a2b3c4d";
    const value = try core.hex_to_u64(hex);
    const result = try core.u64_to_hex(std.testing.allocator, value);
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings(hex, result);
}

test "hex conversion with zero" {
    const hex = "0";
    const value = try core.hex_to_u64(hex);
    const result = try core.u64_to_hex(std.testing.allocator, value);
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings(hex, result);
}

test "hex conversion with max u64 value" {
    const hex = "ffffffffffffffff";
    const value = try core.hex_to_u64(hex);
    const result = try core.u64_to_hex(std.testing.allocator, value);
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings(hex, result);
}
