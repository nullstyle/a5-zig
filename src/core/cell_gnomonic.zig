const std = @import("std");
const Radians = @import("coordinate_systems").Radians;
const Polar = @import("coordinate_systems").Polar;
const Spherical = @import("coordinate_systems").Spherical;

pub const GnomonicProjection = struct {
    pub fn forward(_: GnomonicProjection, spherical: Spherical) Polar {
        const theta = spherical.theta();
        const phi = spherical.phi();
        return Polar.new(std.math.tan(phi.get()), theta);
    }

    pub fn inverse(_: GnomonicProjection, polar: Polar) Spherical {
        return Spherical.new(
            polar.gamma(),
            Radians.new_unchecked(std.math.atan(polar.rho())),
        );
    }
};
