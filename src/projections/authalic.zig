const core = @import("core");
const Radians = @import("coordinate_systems").Radians;
const core_authalic = core.authalic;

pub const AuthalicProjection = struct {
    pub fn forward(_: AuthalicProjection, phi: Radians) Radians {
        return core_authalic.forward(phi);
    }

    pub fn inverse(_: AuthalicProjection, phi: Radians) Radians {
        return core_authalic.inverse(phi);
    }
};
