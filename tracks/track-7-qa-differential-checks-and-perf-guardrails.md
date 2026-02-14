# Track 7: QA, Differential Checks, and Perf Guardrails (Agent G)

## Scope from plan

- Owns:
  - Cross-track verification
  - Rust-vs-Zig parity spot checks
  - Perf and memory smoke checks
  - Release gates

## Context (Track 6 Integrated)

- Track 6 (`core/cell`, `core/compact`, and public API re-exports) is now integrated.
- Track 7 gates now include deterministic differential and smoke coverage for Track 6 APIs in addition to Tracks 0-5.

## Concrete tasks

- [x] Add cross-track parity verification gate for completed tracks via `zig build qa` (`qa` depends on `test`).
- [x] Add deterministic Rust-fixture differential spot checks for high-risk bit/hierarchy cases (`tests/qa_differential_guardrails.zig`).
- [x] Add perf and memory smoke checks (`tests/qa_perf_memory_smoke.zig`).
- [x] Validate and enforce release-gate entrypoint via `zig build release-gates`.
- [x] Add deterministic seeds for randomized/sampled validation.
- [x] Build regression coverage for:
  - antimeridian geometry
  - high-latitude geometry
- [x] Verify projection drift remains below tolerance budgets in deterministic seeded checks.
- [x] Verify serialization/hierarchy bit-level expectations remain exact against pinned Rust fixture IDs.
- [x] Remove prior Track 6 blocker and include cell/compact in release-gate coverage.

## Dependencies

- Final hardening track (Wave C) after prior tracks provide stable deliverables.
