# Track 1: Coordinate and Math Primitives (Agent A)

## Scope from plan

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

## Concrete tasks

- [ ] Port `coordinate_systems/*` modules.
- [ ] Port `core/constants`.
- [ ] Port `core/hex`.
- [ ] Port `utils/vector`.
- [ ] Port and validate `tests/hex.rs`.
- [ ] Port and validate `tests/vector.rs`.
- [ ] Port relevant `tests/coordinate_transforms.rs` sections assigned to this track.
- [ ] Port and validate portions of:
  - `tests/gnomonic.rs`
  - `tests/authalic.rs` related to primitives.
- [ ] Keep this track’s test subset green continuously.

## Dependencies

- Must coordinate with Tracks 5 and others touching projection/math behavior.

