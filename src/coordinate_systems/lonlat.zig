const Degrees = @import("base.zig").Degrees;

pub const LonLat = struct {
    longitude_value: Degrees,
    latitude_value: Degrees,

    pub fn new(lon: f64, lat: f64) LonLat {
        return .{
            .longitude_value = Degrees.new(lon),
            .latitude_value = Degrees.new(lat),
        };
    }

    pub fn new_unchecked(lon: Degrees, lat: Degrees) LonLat {
        return .{ .longitude_value = lon, .latitude_value = lat };
    }

    pub fn longitude(self: LonLat) f64 {
        return self.longitude_value.get();
    }

    pub fn latitude(self: LonLat) f64 {
        return self.latitude_value.get();
    }

    pub fn to_degrees(self: LonLat) [2]f64 {
        return .{ self.longitude(), self.latitude() };
    }

    pub fn from_tuple(value: [2]f64) LonLat {
        return new(value[0], value[1]);
    }
};
