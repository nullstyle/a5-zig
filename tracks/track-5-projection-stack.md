# Track 5: Projection Stack (Agent E)

## Scope from plan

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

## Concrete tasks

- [x] Port `core/coordinate_transforms`.
- [x] Port `projections/authalic`.
- [x] Port `projections/gnomonic`.
- [x] Port `projections/polyhedral`.
- [x] Port `projections/dodecahedron`.
- [x] Port and validate `tests/coordinate_transforms.rs`.
- [x] Port and validate `tests/authalic.rs`.
- [x] Port and validate `tests/gnomonic.rs`.
- [x] Port and validate `tests/polyhedral.rs`.
- [x] Port and validate `tests/dodecahedron.rs`.
- [x] Respect projection drift tolerances test-by-test.
- [x] Keep this track’s test subset green.

## Dependencies

- Wave B track: start after (1,3,4) foundations are green.
