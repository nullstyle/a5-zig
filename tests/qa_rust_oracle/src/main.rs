use a5::coordinate_systems::LonLat;
use a5::core::cell::{cell_to_boundary, lonlat_to_cell, CellToBoundaryOptions};
use a5::core::hex::{hex_to_u64, u64_to_hex};
use a5::core::serialization::{cell_to_children, WORLD_CELL};
use std::env;
use std::process;

fn usage() {
    eprintln!("Usage:");
    eprintln!("  cargo run --manifest-path tests/qa_rust_oracle/Cargo.toml -- cell-ids <resolution>");
    eprintln!("  cargo run --manifest-path tests/qa_rust_oracle/Cargo.toml -- cell-boundaries <cell_hex> [<cell_hex>...]");
    eprintln!("  cargo run --manifest-path tests/qa_rust_oracle/Cargo.toml -- lonlat-to-cell <resolution> <lon,lat> [<lon,lat>...]");
}

fn run_cell_ids(args: &[String]) {
    if args.len() != 1 {
        usage();
        process::exit(1);
    }

    let resolution = match args[0].parse::<i32>() {
        Ok(value) => value,
        Err(_) => {
            eprintln!("Invalid resolution: {}", args[0]);
            process::exit(1);
        }
    };

    match cell_to_children(WORLD_CELL, Some(resolution)) {
        Ok(cell_ids) => {
            for id in cell_ids {
                println!("{}", u64_to_hex(id));
            }
        }
        Err(error) => {
            eprintln!("Failed to generate cells for resolution {}: {}", resolution, error);
            process::exit(1);
        }
    }
}

fn run_cell_boundaries(args: &[String]) {
    if args.is_empty() {
        usage();
        process::exit(1);
    }

    for cell_hex in args {
        let cell_id = match hex_to_u64(cell_hex) {
            Ok(id) => id,
            Err(error) => {
                eprintln!("Invalid cell hex {}: {}", cell_hex, error);
                process::exit(1);
            }
        };

        let boundary = match cell_to_boundary(
            cell_id,
            Some(CellToBoundaryOptions {
                closed_ring: true,
                segments: Some(1),
            }),
        ) {
            Ok(points) => points,
            Err(error) => {
                eprintln!("Failed to compute boundary for {}: {}", cell_hex, error);
                process::exit(1);
            }
        };

        print!("{}\t", u64_to_hex(cell_id));
        for (index, point) in boundary.iter().enumerate() {
            if index > 0 {
                print!(";");
            }
            print!("{:.15},{:.15}", point.longitude(), point.latitude());
        }
        println!();
    }
}

fn run_lonlat_to_cell(args: &[String]) {
    if args.len() < 2 {
        usage();
        process::exit(1);
    }

    let resolution = match args[0].parse::<i32>() {
        Ok(value) => value,
        Err(_) => {
            eprintln!("Invalid resolution: {}", args[0]);
            process::exit(1);
        }
    };

    for point in &args[1..] {
        let (lon_text, lat_text) = match point.split_once(',') {
            Some(parts) => parts,
            None => {
                eprintln!("Invalid lon,lat pair: {}", point);
                process::exit(1);
            }
        };

        let lon = match lon_text.parse::<f64>() {
            Ok(value) => value,
            Err(_) => {
                eprintln!("Invalid longitude: {}", lon_text);
                process::exit(1);
            }
        };
        let lat = match lat_text.parse::<f64>() {
            Ok(value) => value,
            Err(_) => {
                eprintln!("Invalid latitude: {}", lat_text);
                process::exit(1);
            }
        };

        let cell_id = match lonlat_to_cell(LonLat::new(lon, lat), resolution) {
            Ok(cell) => cell,
            Err(error) => {
                eprintln!(
                    "Failed to compute lonlat_to_cell for lon={}, lat={}, resolution={}: {}",
                    lon, lat, resolution, error
                );
                process::exit(1);
            }
        };

        println!("{}", u64_to_hex(cell_id));
    }
}

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    if args.is_empty() {
        usage();
        process::exit(1);
    }

    let command = &args[0];
    let command_args = &args[1..];

    match command.as_str() {
        "cell-ids" => run_cell_ids(command_args),
        "cell-boundaries" => run_cell_boundaries(command_args),
        "lonlat-to-cell" => run_lonlat_to_cell(command_args),
        _ => {
            eprintln!("Unknown command: {}", command);
            usage();
            process::exit(1);
        }
    }
}
