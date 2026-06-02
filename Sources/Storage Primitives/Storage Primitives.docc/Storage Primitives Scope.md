# Storage Primitives Scope

`swift-storage-primitives` provides the **typed-element storage substrate** —
the namespace, lifecycle-tracking primitives, field-handle, and accessor-tag types
over which concrete storage disciplines compose. Each storage discipline (Heap,
Inline, Pool, Arena, Pool.Inline, Arena.Inline, Slab, Split) is its own sibling
package; this package owns the cross-discipline substrate they share.

## Per-[MOD-031] shape

The package follows `[MOD-031]` per-sub-namespace decomposition: each sub-namespace
(`Storage.Initialization`, `Storage.Field`, `Storage.Error`, accessor tags) is its
own target, with `Storage Primitive` as the layer-invariant namespace target per
`[MOD-017]`. There is no `Storage Primitives Core` target — the legacy `[MOD-001]`
Core convention is deprecated and was retired from this package during the Cohort III
extraction (2026-05-23).

## Owner targets

- **Storage Primitive** — the `public enum Storage<Element: ~Copyable> {}` namespace
  target. Zero external deps per `[MOD-017]`'s invariant.
- **Storage Error Primitives** — the `Storage.Error` enum (typed-throws error
  namespace for tracked operations: `capacityExceeded`, `empty`).
- **Storage Initialization Primitives** — the `Storage.Initialization` enum
  (`empty` / `one(span)` / `two(first, second)`) and its iteration / range /
  factory operations. Used by every storage discipline that tracks which slots
  hold initialized elements.
- **Storage Field Primitives** — the `Storage.Field<Value>` field-handle type.
  General layout truth (byte offset + stride). Depends on `swift-affine-primitives`
  for the typed `Affine.Discrete.Ratio<Value, Memory>` stride encoding.
- **Storage Accessor Primitives** — the `Storage.Initialize`, `Storage.Deinitialize`,
  `Storage.Copy`, `Storage.Move` accessor-tag types (phantom-type tags for typed
  accessor APIs on storage disciplines).
- **Storage Primitives** — umbrella; re-exports all sub-namespace targets so that
  consumers needing the union write `import Storage_Primitives`.
- **Storage Primitives Test Support** — published test-fixtures product; spine
  anchor on `Memory Primitives Test Support` per `[MOD-024]`.

## Out of scope (siblings)

The following storage disciplines are EACH their own sibling package. Each
USES `Memory.{Address, Alignment, Contiguous}` + `Memory.{Pool, Arena}` substrate
where applicable, plus owner sub-namespace targets (`Storage Primitive`,
`Storage Initialization Primitives`, …) as each discipline requires.

- `Storage.Heap` (tracked-initialization heap storage) → `swift-storage-heap-primitives`
- `Storage.Inline<capacity>` (stack-allocated inline with bit-vector tracking) → `swift-storage-inline-primitives`
- `Storage.Pool` (bitmap-tracked slot allocation; wraps `Memory.Pool`) → `swift-storage-pool-primitives`
- `Storage.Pool.Inline<N>` (inline pool storage) → `swift-storage-pool-inline-primitives`
- `Storage.Arena` (generation-token arena; wraps `Memory.Arena`) → `swift-storage-arena-primitives`
- `Storage.Arena.Inline<N>` (inline arena storage) → `swift-storage-arena-inline-primitives`
- `Storage.Slab` (heap + bitmap slab allocator) → `swift-storage-slab-primitives`
- `Storage.Split<Lane>` (dual-array SoA with consumer-defined metadata) → `swift-storage-split-primitives`

## Evaluation rule

Sub-target additions are evaluated against this scope.

- A proposed addition that is a **storage discipline** (a way of organizing
  element storage with a distinct lifecycle / allocation pattern) extracts to
  a sibling package, not into this one.
- A proposed addition that is **cross-discipline substrate** (namespace decl,
  lifecycle state, error namespace, layout handle, accessor tag) lands as a
  new sub-namespace target in this package, per `[MOD-031]`.
- A proposed addition that mixes the two — e.g., a discipline-specific helper
  conceptually general but never actually used outside one discipline — defaults
  to staying with the discipline's sibling package until a second consumer
  surfaces.
