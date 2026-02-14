# Track 6: Cell API, Compaction, Integration Surface (Agent F)

## Scope from plan

- Owns:
  - `core/cell`
  - `core/compact`
- Public re-export layer in `src/root.zig`
  - Optional wireframe parity example
- Primary test files:
  - `tests/cell.rs`
  - `tests/compact.rs`
  - API smoke tests

## Concrete tasks

- [x] Port `core/cell`.
- [x] Port `core/compact`.
- [x] Implement/finish public API re-exports in `src/root.zig`.
- [x] Port and validate `tests/cell.rs`.
- [x] Port and validate `tests/compact.rs`.
- [x] Add/update API smoke tests.
- [x] Maintain known behavior quirks during parity phase.
- [x] Keep track test subset green and integrate with broader API.
- [ ] Optionally add wireframe parity example.

## Dependencies

- Wave B track: start after Tracks 2 and 3 foundations are green, integrate incrementally with Track 5.
