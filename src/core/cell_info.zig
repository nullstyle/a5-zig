const serialization = @import("serialization.zig");

pub const FIRST_HILBERT_RESOLUTION: i32 = serialization.FIRST_HILBERT_RESOLUTION;

const AUTHALIC_AREA: f64 = 510065624779439.1;

pub fn get_num_cells(resolution: i32) u64 {
    if (resolution < 0) {
        return 0;
    }
    if (resolution == 0) {
        return 12;
    }

    if (resolution == 28) {
        return 1080863910568919000;
    }
    if (resolution == 29) {
        return 4323455642275676000;
    }
    if (resolution == 30) {
        return 17293822569102705000;
    }

    var count: u64 = 60;
    var i: i32 = 1;
    while (i < resolution) : (i += 1) {
        count *= 4;
    }
    return count;
}

pub fn get_num_children(parent_resolution: i32, child_resolution: i32) usize {
    if (child_resolution < parent_resolution) {
        return 0;
    }
    if (child_resolution == parent_resolution) {
        return 1;
    }
    if (parent_resolution >= FIRST_HILBERT_RESOLUTION) {
        var count: usize = 1;
        var i: i32 = parent_resolution;
        while (i < child_resolution) : (i += 1) {
            count *= 4;
        }
        return count;
    }

    const parent_count = blk: {
        const raw = get_num_cells(parent_resolution);
        break :blk if (raw == 0) @as(u64, 1) else raw;
    };
    const child_count = get_num_cells(child_resolution);
    return @intCast(child_count / parent_count);
}

pub fn cell_area(resolution: i32) f64 {
    if (resolution < 0) {
        return AUTHALIC_AREA;
    }

    return switch (resolution) {
        0 => 42505468731619.93,
        1 => 8501093746323.985,
        2 => 2125273436580.9963,
        3 => 531318359145.2491,
        4 => 132829589786.31227,
        5 => 33207397446.578068,
        6 => 8301849361.644517,
        7 => 2075462340.4111292,
        8 => 518865585.1027823,
        9 => 129716396.27569558,
        10 => 32429099.068923894,
        11 => 8107274.767230974,
        12 => 2026818.6918077434,
        13 => 506704.67295193585,
        14 => 126676.16823798396,
        15 => 31669.04205949599,
        16 => 7917.260514873998,
        17 => 1979.3151287184994,
        18 => 494.82878217962485,
        19 => 123.70719554490621,
        20 => 30.926798886226553,
        21 => 7.731699721556638,
        22 => 1.9329249303891596,
        23 => 0.4832312325972899,
        24 => 0.12080780814932247,
        25 => 0.03020195203733062,
        26 => 0.007550488009332655,
        27 => 0.0018876220023331637,
        28 => 0.0004719055005832909,
        29 => 0.00011797637514582273,
        30 => 0.000029494093786455682,
        else => AUTHALIC_AREA / @as(f64, @floatFromInt(get_num_cells(resolution))),
    };
}
