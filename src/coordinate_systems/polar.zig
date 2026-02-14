const Radians = @import("base.zig").Radians;
const Spherical = @import("spherical.zig").Spherical;

pub const Polar = struct {
    rho_value: f64,
    gamma_value: Radians,

    pub fn new(rho_value: f64, gamma_value: Radians) Polar {
        return .{ .rho_value = rho_value, .gamma_value = gamma_value };
    }

    pub fn rho(self: Polar) f64 {
        return self.rho_value;
    }

    pub fn gamma(self: Polar) Radians {
        return self.gamma_value;
    }

    pub fn project_gnomonic(self: Polar) Spherical {
        return Spherical.new(self.gamma_value, Radians.new_unchecked(self.rho_value.atan()));
    }
};
