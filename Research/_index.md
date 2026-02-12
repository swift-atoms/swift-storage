# Storage Primitives Research

Research documents backing the storage-primitives implementation.

## Documents

| Document | Topic | Status |
|----------|-------|--------|
| [storage-ownership-reference-synthesis](storage-ownership-reference-synthesis.md) | Master synthesis: conceptual model, canonical primitives, layering | DECISION |
| [storage-contiguous-api-design](storage-contiguous-api-design.md) | Span/MutableSpan API surface design | DECISION |
| [storage-contiguous-protocol-conformance](storage-contiguous-protocol-conformance.md) | Memory.Contiguous.Protocol conformance | DECISION |
| [storage-inline-invariants](storage-inline-invariants.md) | Complete invariant catalog for Storage.Inline | DECISION |
| [inline-slot-type-organization](inline-slot-type-organization.md) | @_rawLayout for automatic optimal layout | RECOMMENDATION |
| [inline-deinitialize-state-reset](inline-deinitialize-state-reset.md) | Preventing double-free footgun in Storage.Inline | RECOMMENDATION |
| [per-slot-initialization-tracking](per-slot-initialization-tracking.md) | BitVector-based per-slot tracking to eliminate footgun | RECOMMENDATION |
| [inline-bitvector-wordcount](inline-bitvector-wordcount.md) | Eliminating wordCount generic parameter | DECISION |
| [inline-storage-read-pointer-escape](inline-storage-read-pointer-escape.md) | Closure-based pointer access pattern | DECISION |
| [ring-buffer-index-arithmetic](ring-buffer-index-arithmetic.md) | Cyclic index arithmetic (ℤ/Nℤ for Bounded, % for dynamic) | DECISION |
| [Collection Primitives Architecture](Collection%20Primitives%20Architecture.md) | Nested Storage classes, ~Copyable patterns | DECISION |
| [split-storage-design](split-storage-design.md) | Tier 2: Field-handle-based dual-lane metadata-driven storage | RECOMMENDATION |
| [split-storage-naming](split-storage-naming.md) | Tier 2: Literature study on naming for dual-lane storage type | RECOMMENDATION |
| [storage-pool-architecture](storage-pool-architecture.md) | Tier 3: Composition vs independence for Storage.Pool | DECISION |
| [noncopyable-copyable-conditional-audit](noncopyable-copyable-conditional-audit.md) | ~Copyable/Copyable conditional support audit across all disciplines | RECOMMENDATION |

## Key Architectural Decisions

### @_rawLayout Migration (2026-02-05)

`Storage.Inline` now uses `@_rawLayout(likeArrayOf: Element, count: capacity)` for automatic optimal layout:
- **Before**: 64-byte fixed slots, physical slot ≠ logical element
- **After**: Element-sized slots, physical slot = logical element (1:1)

This enables Span access for Copyable elements and eliminates the slot/element distinction.

### Storage Primitives

| Type | Placement | Lifetime | Layout | Init Tracking |
|------|-----------|----------|--------|---------------|
| `Storage.Heap` | Heap | ARC | Dense (element stride) | `Storage.Initialization` |
| `Storage.Inline<Element, capacity>` | Inline | Lexical | Dense (@_rawLayout) | `Bit.Vector.Static` |
| `Storage.Split<Lane>` (proposed) | Heap | ARC | Dual-lane `[Lane...][Element...]` | None (metadata-driven) |
| `Storage.Pool` | Heap | ARC | Dense (element stride) | `Bit.Vector` (per-slot) |

`Heap` and `Inline` support `~Copyable` elements and conform to `Memory.Contiguous.Protocol` for Copyable elements. `Split` (see `split-storage-design.md` v3.0.0) is proposed for metadata-driven dual-array structures like hash table metadata+payload. Access is via field handles (`Storage.Field<Value>`); design converged via Claude-ChatGPT collaborative review.

## Status Legend

| Status | Meaning |
|--------|---------|
| DECISION | Final decision documented and implemented |
| RECOMMENDATION | Analysis complete, recommendation made |
