const std = @import("std");

pub fn hex_to_u64(hex: []const u8) !u64 {
    return try std.fmt.parseInt(u64, hex, 16);
}

pub fn u64_to_hex(allocator: std.mem.Allocator, value: u64) ![]u8 {
    return try std.fmt.allocPrint(allocator, "{x}", .{value});
}
