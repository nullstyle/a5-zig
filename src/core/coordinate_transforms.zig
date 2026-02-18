const std = @import("std");
const coordinate_systems = @import("coordinate_systems");
const authalic = @import("authalic.zig");
const pentagon = @import("pentagon.zig");

const Degrees = coordinate_systems.Degrees;
const Radians = coordinate_systems.Radians;
const Barycentric = coordinate_systems.Barycentric;
const Cartesian = coordinate_systems.Cartesian;
const Face = coordinate_systems.Face;
const FaceTriangle = coordinate_systems.FaceTriangle;
const IJ = coordinate_systems.IJ;
const KJ = coordinate_systems.KJ;
const LonLat = coordinate_systems.LonLat;
const Polar = coordinate_systems.Polar;
const Spherical = coordinate_systems.Spherical;

pub const LONGITUDE_OFFSET: f64 = 93.0;

pub fn deg_to_rad(deg: Degrees) Radians {
    return Radians.new_unchecked(deg.get() * (std.math.pi / 180.0));
}

pub fn rad_to_deg(rad: Radians) Degrees {
    return Degrees.new_unchecked(rad.get() * (180.0 / std.math.pi));
}

pub fn to_polar(face: Face) Polar {
    const x = face.x();
    const y = face.y();
    const rho = std.math.sqrt(x * x + y * y);
    const gamma = Radians.new_unchecked(std.math.atan2(y, x));
    return Polar.new(rho, gamma);
}

pub fn to_face(polar: Polar) Face {
    const rho = polar.rho();
    const gamma = polar.gamma();
    const gamma_val = gamma.get();
    const x = rho * std.math.cos(gamma_val);
    const y = rho * std.math.sin(gamma_val);
    return Face.new(x, y);
}

pub fn face_to_barycentric(p: Face, triangle: FaceTriangle) Barycentric {
    const p1 = triangle.a;
    const p2 = triangle.b;
    const p3 = triangle.c;

    const d31_x = p1.x() - p3.x();
    const d31_y = p1.y() - p3.y();
    const d23_x = p3.x() - p2.x();
    const d23_y = p3.y() - p2.y();
    const d3p_x = p.x() - p3.x();
    const d3p_y = p.y() - p3.y();

    const det = d23_x * d31_y - d23_y * d31_x;
    const b0 = (d23_x * d3p_y - d23_y * d3p_x) / det;
    const b1 = (d31_x * d3p_y - d31_y * d3p_x) / det;
    const b2 = 1.0 - (b0 + b1);

    return Barycentric.new(b0, b1, b2);
}

pub fn barycentric_to_face(bary: Barycentric, triangle: FaceTriangle) Face {
    const p1 = triangle.a;
    const p2 = triangle.b;
    const p3 = triangle.c;

    const x = bary.u * p1.x() + bary.v * p2.x() + bary.w * p3.x();
    const y = bary.u * p1.y() + bary.v * p2.y() + bary.w * p3.y();

    return Face.new(x, y);
}

pub fn to_spherical(cart: Cartesian) Spherical {
    const x = cart.x();
    const y = cart.y();
    const z = cart.z();

    const theta = Radians.new_unchecked(std.math.atan2(y, x));
    const r = std.math.sqrt(x * x + y * y + z * z);
    const phi = Radians.new_unchecked(std.math.acos(z / r));

    return Spherical.new(theta, phi);
}

pub fn to_cartesian(spherical: Spherical) Cartesian {
    const theta = spherical.theta();
    const phi = spherical.phi();

    const sin_phi = std.math.sin(phi.get());
    const x = sin_phi * std.math.cos(theta.get());
    const y = sin_phi * std.math.sin(theta.get());
    const z = std.math.cos(phi.get());

    return Cartesian.new(x, y, z);
}

pub fn from_lon_lat(lonlat: LonLat) Spherical {
    const theta = deg_to_rad(Degrees.new_unchecked(lonlat.longitude() + LONGITUDE_OFFSET));
    const geodetic_lat = deg_to_rad(Degrees.new_unchecked(lonlat.latitude()));

    const authalic_lat = authalic.forward(geodetic_lat);
    const phi = Radians.new_unchecked(std.math.pi / 2.0 - authalic_lat.get());

    return Spherical.new(theta, phi);
}

pub fn to_lon_lat(spherical: Spherical) LonLat {
    const theta = spherical.theta();
    const phi = spherical.phi();

    const longitude = rad_to_deg(theta).get() - LONGITUDE_OFFSET;
    const authalic_lat = Radians.new_unchecked(std.math.pi / 2.0 - phi.get());
    const geodetic_lat = authalic.inverse(authalic_lat);
    const latitude = rad_to_deg(geodetic_lat);

    return LonLat.new(longitude, latitude.get());
}

pub fn face_to_ij(face: Face) IJ {
    const basis_inverse_mat = pentagon.basis_inverse();
    const x = face.x();
    const y = face.y();
    const u = basis_inverse_mat.m00 * x + basis_inverse_mat.m01 * y;
    const v = basis_inverse_mat.m10 * x + basis_inverse_mat.m11 * y;
    return IJ.new(u, v);
}

pub fn ij_to_face(ij: IJ) Face {
    const basis_mat = pentagon.basis();
    const u = ij.x();
    const v = ij.y();
    const x = basis_mat.m00 * u + basis_mat.m01 * v;
    const y = basis_mat.m10 * u + basis_mat.m11 * v;
    return Face.new(x, y);
}

pub fn face_to_kj(face: Face) KJ {
    return KJ.new(face.x(), face.y());
}

pub fn normalize_longitude(value: f64) f64 {
    const v = value + 180.0;
    return v - std.math.floor(v / 360.0) * 360.0 - 180.0;
}

pub fn normalize_longitudes(allocator: std.mem.Allocator, contour: []const LonLat) ![]LonLat {
    if (contour.len == 0) {
        return try allocator.dupe(LonLat, contour);
    }

    var cx: f64 = 0.0;
    var cy: f64 = 0.0;
    var cz: f64 = 0.0;
    for (contour) |point| {
        const point_cart = to_cartesian(from_lon_lat(point));
        cx += point_cart.x();
        cy += point_cart.y();
        cz += point_cart.z();
    }

    const center_len = std.math.sqrt(cx * cx + cy * cy + cz * cz);
    const normalized_center = if (center_len > 0.0) Cartesian.new(cx / center_len, cy / center_len, cz / center_len) else Cartesian.new(0.0, 0.0, 0.0);
    const center_spherical = to_spherical(normalized_center);
    const center_lonlat = to_lon_lat(center_spherical);
    var center_lon = center_lonlat.longitude();
    const center_lat = center_lonlat.latitude();

    if (!(-89.99 <= center_lat and center_lat <= 89.99)) {
        center_lon = contour[0].longitude();
    }

    center_lon = normalize_longitude(center_lon);

    var out = try allocator.dupe(LonLat, contour);
    var i: usize = 0;
    while (i < out.len) : (i += 1) {
        var longitude = out[i].longitude();
        const latitude = out[i].latitude();
        while (longitude - center_lon > 180.0) {
            longitude -= 360.0;
        }
        while (longitude - center_lon < -180.0) {
            longitude += 360.0;
        }
        out[i] = LonLat.new(longitude, latitude);
    }

    return out;
}

pub const Contour = []LonLat;
