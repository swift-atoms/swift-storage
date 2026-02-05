# Storage Primitives Research

Centralized research for storage, buffer, and ADT primitives design.

This directory consolidates all storage-related research from:
- `swift-storage-primitives/Research/` (original)
- `swift-memory-primitives/Research/` (buffer/storage docs moved 2026-02-03)
- `swift-primitives/Research/` (storage-related docs moved 2026-02-03)
- `swift-queue-primitives/Research/` (collection architecture moved 2026-02-03)
- `swift-primitives/Documentation.docc/Research/` (queue integration moved 2026-02-03)
- `swift-institute/Research/` (collection/range semantics moved 2026-02-03)
- `swift-institute/Documentation.docc/` (data structures catalog moved 2026-02-03)

## Synthesis

| Document | Topic | Status |
|----------|-------|--------|
| [storage-ownership-reference-synthesis](storage-ownership-reference-synthesis.md) | **Master synthesis**: conceptual map, canonical set proposals, trade-off analysis, recommendation | IN_PROGRESS |

## API Design

| Document | Topic | Status |
|----------|-------|--------|
| [storage-primitives-canonical-api](storage-primitives-canonical-api.md) | Canonical public API surface derived from first principles | IN_PROGRESS |
| [storage-contiguous-protocol-conformance](storage-contiguous-protocol-conformance.md) | Memory.Contiguous.Protocol conformance for Storage.Heap/Inline | DECISION |
| [storage-contiguous-api-design](storage-contiguous-api-design.md) | Optimal API surface for contiguous memory access (Span integration) | DECISION |

## Foundational Research

| Document | Topic | Status |
|----------|-------|--------|
| [storage-primitives-first-principles](storage-primitives-first-principles.md) | Academic lit review: Scott-Strachey, linear logic, ownership types, storage taxonomy (7 variants) | IN_PROGRESS |
| [storage-primitives-design](storage-primitives-design.md) | Original architectural proposal: Layout types, headers, ring ops, migration path | SUPERSEDED |
| [unified-storage-primitive](unified-storage-primitive.md) | Layered approach: Storage.Dynamic for Array/Stack, custom for Queue/Hash.Table | RECOMMENDATION |
| [buffer-algebraic-structure](buffer-algebraic-structure.md) | Buffers as ad-hoc structs, not Tagged intervals — universal precedent survey | IN_PROGRESS |
| [buffer-base-nullability](buffer-base-nullability.md) | Property pattern for nullable vs non-null buffer base address | DECISION |

## Index and Arithmetic

| Document | Topic | Status |
|----------|-------|--------|
| [ring-buffer-index-arithmetic](ring-buffer-index-arithmetic.md) | Two-tier: ℤ/Nℤ cyclic group for Bounded, % projection for dynamic | DECISION |

## Inline Storage

| Document | Topic | Status |
|----------|-------|--------|
| [storage-inline-invariants](storage-inline-invariants.md) | Complete invariant catalog: layout, initialization, ownership, preconditions | DECISION |
| [inline-storage-read-pointer-escape](inline-storage-read-pointer-escape.md) | Closure-based fix for Storage.Static pointer escape | DECISION |
| [inline-storage-span-access](inline-storage-span-access.md) | 64-byte slots prevent dense Span; natural split static vs heap (superseded by @_rawLayout) | SUPERSEDED |
| [inline-variant-naming-consistency](inline-variant-naming-consistency.md) | Inline = all-N-initialized, Static = 0-to-N variable (superseded at storage layer by placement-based naming) | CONTEXTUALLY SUPERSEDED |
| [inline-storage-slot-sizing-for-vectors](inline-storage-slot-sizing-for-vectors.md) | 64-byte slots necessary for ~Copyable; overhead analysis (superseded by @_rawLayout) | SUPERSEDED |
| [inline-slot-type-organization](inline-slot-type-organization.md) | @_rawLayout for automatic optimal layout; fallback to parameterized slot | RECOMMENDATION |

## Collection Architecture

| Document | Topic | Status |
|----------|-------|--------|
| [Collection Primitives Architecture](Collection%20Primitives%20Architecture.md) | Nested Storage classes, variant system, ~Copyable patterns | DECISION |
| [queue-cyclic-index-storage-integration](queue-cyclic-index-storage-integration.md) | Cyclic index NOT viable for dynamic Queue | IN_PROGRESS |

## Integration and Layering

| Document | Topic | Status |
|----------|-------|--------|
| [integration-maximization-comparative-analysis](integration-maximization-comparative-analysis.md) | DIR/TIR/ASC metrics, pointer-primitives integration gaps | RECOMMENDATION |

## Collection Semantics

| Document | Topic | Status |
|----------|-------|--------|
| [finite-collection-join-point-integration](finite-collection-join-point-integration.md) | Collections orthogonal to finite types; integration at join-points | RECOMMENDATION |
| [range-sequence-collection-semantic-analysis](range-sequence-collection-semantic-analysis.md) | Range.Lazy cannot conform to Sequence.Protocol with ~Copyable | — |

## Reference Catalog

| Document | Topic | Status |
|----------|-------|--------|
| [data-structures-catalog](data-structures-catalog.md) | Complete ADT catalog: 12+ types, 4 storage strategies | REFERENCE |

## Status Legend

| Status | Meaning |
|--------|---------|
| IN_PROGRESS | Active research or design work |
| RECOMMENDATION | Analysis complete, recommendation made |
| DECISION | Final decision documented and accepted |
| SUPERSEDED | Replaced by newer research |
| REFERENCE | Descriptive catalog, not a decision document |
