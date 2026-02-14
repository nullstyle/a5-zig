# Track 0: Infra and Shared Contracts (Integrator)

## Scope from plan

- Owns:
  - Zig test harness
  - Shared test helpers
  - Fixture loading utilities
  - Module import conventions
- Deliverables:
  - `zig build test` entrypoint
  - Stable helper assertions and fixture parsers
  - Canonical module map for all tracks

## Primary responsibilities

- Set up the Zig test harness and ensure the baseline test command is reproducible.
- Build shared helper utilities used across tracks.
- Implement fixture loading/parsing so all tracks can consume Rust parity fixtures consistently.
- Define and enforce module import conventions.
- Maintain a canonical module map and shared exports used by all tracks.
- Keep subset suites green per merge as other tracks land changes.

## Concrete tasks

- [ ] Create Zig test scaffolding mirroring Rust test files by track.
- [ ] Implement shared test helpers and fixture parsers.
- [ ] Standardize module import conventions and update build/test wiring.
- [ ] Create `zig build test` entrypoint.
- [ ] Set up stable helper assertions for parity comparisons.
- [ ] Track and fix cross-track integration issues from shared modules.
- [ ] Maintain track-owned test green while integrating others.

## Owned test targets

- Project-wide harness tests and shared fixtures for all tracks.

