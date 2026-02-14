const std = @import("std");

pub const Degrees = struct {
    value: f64,

    pub fn new_unchecked(value: f64) Degrees {
        return .{ .value = value };
    }

    pub fn new(value: f64) Degrees {
        return .{ .value = value };
    }

    pub fn get(self: Degrees) f64 {
        return self.value;
    }

    pub fn to_radians(self: Degrees) Radians {
        return Radians.new_unchecked(self.value * (std.math.pi / 180.0));
    }
};

pub const Radians = struct {
    value: f64,

    pub fn new_unchecked(value: f64) Radians {
        return .{ .value = value };
    }

    pub fn new(value: f64) Radians {
        const tau = std.math.tau;
        const normalized = value - std.math.floor(value / tau) * tau;
        return .{ .value = if (normalized < 0.0) normalized + tau else normalized };
    }

    pub fn get(self: Radians) f64 {
        return self.value;
    }

    pub fn to_degrees(self: Radians) Degrees {
        return Degrees.new_unchecked(self.value * (180.0 / std.math.pi));
    }
};
