const std = @import("std");
const Radians = @import("coordinate_systems").Radians;

pub const GEODETIC_TO_AUTHALIC = [_]f64{
    -2.239_209_838_678_639_4e-03,
    2.130_860_651_325_021_7e-06,
    -2.559_257_686_421_274_2e-09,
    3.370_196_526_780_283_7e-12,
    -4.667_545_312_611_248_7e-15,
    6.674_928_703_848_159_6e-18,
};

pub const AUTHALIC_TO_GEODETIC = [_]f64{
    2.239_208_996_354_165_7e-03,
    2.883_197_804_860_755_6e-06,
    5.086_220_739_972_660_3e-09,
    1.020_181_237_781_610_0e-11,
    2.191_287_230_676_771_8e-14,
    4.928_423_548_252_380_6e-17,
};

pub fn apply_coefficients(phi: Radians, c: *const [6]f64) Radians {
    const sin_phi = std.math.sin(phi.get());
    const cos_phi = std.math.cos(phi.get());
    const x = 2.0 * (cos_phi - sin_phi) * (cos_phi + sin_phi);

    var coef_0 = x * c[5] + c[4];
    var coef_1 = x * coef_0 + c[3];
    coef_0 = x * coef_1 - coef_0 + c[2];
    coef_1 = x * coef_0 - coef_1 + c[1];
    coef_0 = x * coef_1 - coef_0 + c[0];

    return Radians.new_unchecked(phi.get() + 2.0 * sin_phi * cos_phi * coef_0);
}

pub fn forward(phi: Radians) Radians {
    return apply_coefficients(phi, &GEODETIC_TO_AUTHALIC);
}

pub fn inverse(phi: Radians) Radians {
    return apply_coefficients(phi, &AUTHALIC_TO_GEODETIC);
}
