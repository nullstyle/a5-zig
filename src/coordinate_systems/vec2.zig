pub const Vec2 = struct {
    x: f64,
    y: f64,

    pub fn new(x: f64, y: f64) Vec2 {
        return .{ .x = x, .y = y };
    }
};
