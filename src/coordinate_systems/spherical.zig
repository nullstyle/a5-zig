const Radians = @import("base.zig").Radians;

pub const Spherical = struct {
    theta_value: Radians,
    phi_value: Radians,

    pub fn new(theta_value: Radians, phi_value: Radians) Spherical {
        return .{ .theta_value = theta_value, .phi_value = phi_value };
    }

    pub fn theta(self: Spherical) Radians {
        return self.theta_value;
    }

    pub fn phi(self: Spherical) Radians {
        return self.phi_value;
    }
};
