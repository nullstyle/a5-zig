const std = @import("std");
const Radians = @import("coordinate_systems").Radians;
const Polar = @import("coordinate_systems").Polar;
const Spherical = @import("coordinate_systems").Spherical;

pub const GnomonicProjection = struct {
    pub fn forward(self: GnomonicProjection, spherical: Spherical) Polar {
        _ = self;
        const theta = spherical.theta();
        const phi = spherical.phi();
        return Polar.new(std.math.tan(phi.get()), theta);
    }

    pub fn inverse(self: GnomonicProjection, polar: Polar) Spherical {
        _ = self;
        return Spherical.new(polar.gamma(), Radians.new_unchecked(std.math.atan(polar.rho())));
    }
};
