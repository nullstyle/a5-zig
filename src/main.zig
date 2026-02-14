const std = @import("std");
const builtin = @import("builtin");
const a5 = @import("a5");

pub fn main() !void {
    if (builtin.os.tag == .freestanding) {
        return;
    }

    try a5.bufferedPrint();
    std.debug.print("Track 0 infra scaffold is active.\n", .{});
}
