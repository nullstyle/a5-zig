# A5 Rust to Zig Port Plan

Date: February 14, 2026

## 1. Scope and Baseline

- Reference source: `/Users/nullstyle/prj.local/a5-zig/ref/a5-rs`
- Reference version: `a5-rs v0.6.2` (changelog date: November 10, 2025)
- Verified baseline state: Rust test suite is green (`cargo test`)
- Verified suite size:
- 150 tests currently run in Rust (`6` unit tests in `src` + `144` integration tests in `tests`)

## 2. Target Zig Structure

- `/Users/nullstyle/prj.local/a5-zig/build.zig`
- `/Users/nullstyle/prj.local/a5-zig/src/root.zig`
- `/Users/nullstyle/prj.local/a5-zig/src/coordinate_systems/*.zig`
- `/Users/nullstyle/prj.local/a5-zig/src/core/*.zig`
- `/Users/nullstyle/prj.local/a5-zig/src/geometry/*.zig`
- `/Users/nullstyle/prj.local/a5-zig/src/projections/*.zig`
- `/Users/nullstyle/prj.local/a5-zig/src/utils/*.zig`
- `/Users/nullstyle/prj.local/a5-zig/tests/*.zig`
- `/Users/nullstyle/prj.local/a5-zig/tests/fixtures/*` (copied once from Rust fixtures and pinned)

## 3. Public API Parity Target

Port and preserve behavior for the Rust public API from `/Users/nullstyle/prj.local/a5-zig/ref/a5-rs/src/lib.rs`:

- `cell_to_boundary`
- `cell_to_lonlat`
- `lonlat_to_cell`
- `hex_to_u64`
- `u64_to_hex`
- `cell_area`
- `get_num_cells`
- `cell_to_children`
- `cell_to_parent`
- `get_res0_cells`
- `get_resolution`
- `compact`
- `uncompact`
- public coordinate types (`Degrees`, `Radians`, `LonLat`)
- cell data type (`A5Cell`)

## 4. TDD Method (Strict)

1. Port tests first (red), implementation second (green), refactor third.
2. Keep fixture-driven behavior identical.
3. Match floating-point tolerances test-by-test.
4. Preserve known behavior quirks first, optimize later.
5. Every merged track must keep its owned test subset green.

## 5. Multi-Agent Parallel Tracks

### Track 0: Infra and Shared Contracts (Integrator)

- Owns:
- Zig test harness
- shared test helpers
- fixture loading utilities
- module import conventions
- Deliverables:
- `zig build test` entrypoint
- stable helper assertions and fixture parsers
- canonical module map for all tracks

### Track 1: Coordinate and Math Primitives (Agent A)

- Owns:
- `coordinate_systems/*`
- `core/constants`
- `core/hex`
- `utils/vector`
- Primary test files:
- `tests/hex.rs`
- `tests/vector.rs`
- portions of `tests/coordinate_transforms.rs`
- `tests/gnomonic.rs`
- `tests/authalic.rs`

### Track 2: Index Encoding and Hierarchy (Agent B)

- Owns:
- `core/hilbert`
- `core/serialization`
- `core/cell_info`
- Primary test files:
- `tests/hilbert.rs`
- `tests/serialization.rs`
- `tests/cell_info.rs`

### Track 3: Geometry, Pentagon, and Tiling (Agent C)

- Owns:
- `geometry/pentagon`
- `geometry/spherical_polygon`
- `geometry/spherical_triangle`
- `core/pentagon`
- `core/tiling`
- Primary test files:
- `tests/pentagon.rs`
- `tests/core_pentagon.rs`
- `tests/spherical_polygon.rs`
- `tests/spherical_triangle.rs`
- `tests/tiling.rs`

### Track 4: Origins, Quaternions, CRS (Agent D)

- Owns:
- `core/dodecahedron_quaternions`
- `core/origin`
- `projections/crs`
- Primary test files:
- `tests/dodecahedron_quaternions.rs`
- `tests/origin.rs`
- `tests/crs.rs`

### Track 5: Projection Stack (Agent E)

- Owns:
- `core/coordinate_transforms`
- `projections/authalic`
- `projections/gnomonic`
- `projections/polyhedral`
- `projections/dodecahedron`
- Primary test files:
- `tests/coordinate_transforms.rs`
- `tests/authalic.rs`
- `tests/gnomonic.rs`
- `tests/polyhedral.rs`
- `tests/dodecahedron.rs`

### Track 6: Cell API, Compaction, Integration Surface (Agent F)

- Owns:
- `core/cell`
- `core/compact`
- public re-export layer in `src/root.zig`
- optional wireframe parity example
- Primary test files:
- `tests/cell.rs`
- `tests/compact.rs`
- API smoke tests

### Track 7: QA, Differential Checks, and Perf Guardrails (Agent G)

- Owns:
- cross-track verification
- Rust-vs-Zig parity spot checks
- perf and memory smoke checks
- release gates

## 6. Dependency Waves

1. Wave A (parallel): Tracks 0, 1, 2, 3, 4
2. Wave B (parallel): Track 5 after (1,3,4) foundations are green; Track 6 after (2,3) with 5 integrated incrementally
3. Wave C: Track 7 hardening, full pass gates, release prep

## 7. Execution Schedule (6-8 Agents)

1. Days 1-2:
- bootstrap Zig harness
- fixture loading
- first red/green cycles on low-dependency modules
2. Days 3-7:
- complete Tracks 1-4
- keep subset suites green continuously
3. Days 8-12:
- complete Tracks 5-6
- finish public API parity
4. Days 13-15:
- Track 7 validation
- differential checks
- documentation and release checklist

Estimated duration: approximately 3 weeks with parallel execution.

## 8. Quality Gates

Required before completion:

1. All Zig port tests pass for ported modules.
2. All fixture-driven parity tests pass against copied fixtures.
3. Public API parity confirmed against Rust exports.
4. No unresolved projection drift beyond defined tolerances.
5. Serialization/hierarchy bit-level tests exactly match expected values.

Recommended additional gates:

1. Add a small Zig tool that compares selected Zig outputs with Rust outputs for high-risk cases.
2. Add deterministic seeds for any randomized or sampled validation.
3. Include a regression suite for antimeridian and high-latitude geometry.

## 9. Known High-Risk Areas and Mitigation

1. Floating-point drift in projection chains
- Mitigation: preserve operation order and constants; avoid fast-math changes during parity phase.
2. Bit encoding drift in serialization/hilbert
- Mitigation: treat mask and resolution tests as blocking gates.
3. Thread-local projection cache behavior
- Mitigation: reproduce with Zig `threadlocal` lazy pattern and validate deterministic behavior.
4. Behavior quirks intentionally mirrored from upstream
- Mitigation: port quirks first; defer cleanup until after parity is complete.

## 10. Immediate Next Actions

1. Create Zig test skeletons mirroring Rust test files by track.
2. Copy fixtures from `/Users/nullstyle/prj.local/a5-zig/ref/a5-rs/tests/fixtures` and `/Users/nullstyle/prj.local/a5-zig/ref/a5-rs/tests/geometry/fixtures` into Zig test fixture paths.
3. Start Wave A with Track 0 and Track 1 in parallel.
