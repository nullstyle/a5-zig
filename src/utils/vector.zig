const std = @import("std");
const coordinate_systems = @import("coordinate_systems");
const Cartesian = coordinate_systems.Cartesian;

pub fn vector_difference(a: Cartesian, b: Cartesian) f64 {
    const midpoint = lerp(a, b, 0.5);
    const midpoint_unit = normalize(midpoint);
    const cross_result = cross(a, midpoint_unit);
    const d = length(cross_result);

    if (d < 1e-8) {
        const ab = subtract(a, b);
        return 0.5 * length(ab);
    }

    return d;
}

pub fn triple_product(a: Cartesian, b: Cartesian, c: Cartesian) f64 {
    const cross_bc = cross(b, c);
    return dot(a, cross_bc);
}

pub fn quadruple_product(a: Cartesian, b: Cartesian, c: Cartesian, d: Cartesian) Cartesian {
    const cross_cd = cross(c, d);
    const triple_acd = dot(a, cross_cd);
    const triple_bcd = dot(b, cross_cd);
    const scaled_a = scale(a, triple_bcd);
    const scaled_b = scale(b, triple_acd);
    return subtract(scaled_b, scaled_a);
}

pub fn slerp(a: Cartesian, b: Cartesian, t: f64) Cartesian {
    const gamma = angle(a, b);
    if (gamma < 1e-12) {
        return lerp(a, b, t);
    }

    const gamma_sin = std.math.sin(gamma);
    const weight_a = std.math.sin((1.0 - t) * gamma) / gamma_sin;
    const weight_b = std.math.sin(t * gamma) / gamma_sin;

    const scaled_a = scale(a, weight_a);
    const scaled_b = scale(b, weight_b);
    return add(scaled_a, scaled_b);
}

pub fn length(v: Cartesian) f64 {
    return std.math.sqrt(v.x() * v.x() + v.y() * v.y() + v.z() * v.z());
}

fn cartesian_value(v: anytype) Cartesian {
    if (@TypeOf(v) == *const Cartesian or @TypeOf(v) == *Cartesian) {
        return v.*;
    }
    return v;
}

pub fn vec3_length(v: anytype) f64 {
    return length(cartesian_value(v));
}

pub fn vec3_distance(a: anytype, b: anytype) f64 {
    return length(subtract(cartesian_value(a), cartesian_value(b)));
}

fn dot(a: Cartesian, b: Cartesian) f64 {
    return a.x() * b.x() + a.y() * b.y() + a.z() * b.z();
}

fn cross(a: Cartesian, b: Cartesian) Cartesian {
    return Cartesian.new(
        a.y() * b.z() - a.z() * b.y(),
        a.z() * b.x() - a.x() * b.z(),
        a.x() * b.y() - a.y() * b.x(),
    );
}

fn normalize(v: Cartesian) Cartesian {
    const len = length(v);
    if (len == 0.0) {
        return v;
    }
    return scale(v, 1.0 / len);
}

fn lerp(a: Cartesian, b: Cartesian, t: f64) Cartesian {
    return Cartesian.new(
        a.x() + t * (b.x() - a.x()),
        a.y() + t * (b.y() - a.y()),
        a.z() + t * (b.z() - a.z()),
    );
}

fn subtract(a: Cartesian, b: Cartesian) Cartesian {
    return Cartesian.new(a.x() - b.x(), a.y() - b.y(), a.z() - b.z());
}

fn add(a: Cartesian, b: Cartesian) Cartesian {
    return Cartesian.new(a.x() + b.x(), a.y() + b.y(), a.z() + b.z());
}

fn scale(v: Cartesian, s: f64) Cartesian {
    return Cartesian.new(v.x() * s, v.y() * s, v.z() * s);
}

fn angle(a: Cartesian, b: Cartesian) f64 {
    const len_a = length(a);
    const len_b = length(b);
    const denom = len_a * len_b;
    if (denom == 0.0) {
        return 0.0;
    }
    const cos_angle = std.math.clamp(dot(a, b) / denom, -1.0, 1.0);
    return std.math.acos(cos_angle);
}
