const std = @import("std");
const a5 = @import("a5");

pub fn main() !void {
    try a5.bufferedPrint();
    std.debug.print("Track 0 infra scaffold is active.\n", .{});
}
