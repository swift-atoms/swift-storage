# ~Copyable and Copyable Conditional Support Audit

<!--
---
version: 1.2.1
last_updated: 2026-03-15
status: DEFERRED
tier: 2
changelog:
  - "1.2.0: Mark analysis phases complete. Experiment and implementation pending."
  - "1.1.0: Incorporate access hierarchy (property > closure > pointer). Reclassify gaps."
  - "1.0.0: Initial audit."
---
-->

## Context

swift-storage-primitives provides four storage disciplines (`Heap`, `Inline`, `Split`, `Pool`) plus two arena variants (`Arena`, `Arena.Inline`), all generic over `Storage<Element: ~Copyable>`. Maximizing ~Copyable support is an explicit design goal — storage primitives sit below collection-level APIs and must support move-only elements.

This audit catalogs the current state of ~Copyable / Copyable conditional support across the entire package, identifies gaps, and recommends concrete actions.

**Trigger**: Proactive design audit [RES-012].

## Question

Where does swift-storage-primitives fall short of maximum ~Copyable element support, and where are Copyable-gated convenience APIs missing?

## Analysis

### Comparative Analysis 1: Type Declarations

All types are assessed for their inherent copyability posture.

| Type | Kind | ~Copyable Element | Type Itself | Assessment |
|------|------|-------------------|-------------|------------|
| `Storage<Element>` | enum | Yes (generic bound) | Copyable (empty enum) | Correct |
| `Storage.Heap` | class (ManagedBuffer) | Yes | Copyable (reference) | Correct |
| `Storage.Inline<capacity>` | struct | Yes | ~Copyable (@_rawLayout) | Correct |
| `Storage.Split<Lane>` | class (ManagedBuffer) | Yes | Copyable (reference) | Correct |
| `Storage.Pool` | class | Yes | Copyable (reference) | Correct |
| `Storage.Pool.Inline<capacity>` | struct | Yes | ~Copyable (@_rawLayout) | Correct |
| `Storage.Arena` | class | Yes | Copyable (reference) | Correct |
| `Storage.Arena.Inline<capacity>` | struct | Yes | ~Copyable (@_rawLayout) | Correct |
| `Storage.Field<Value>` | struct | N/A (Value: ~Copyable) | Copyable, Sendable | Correct |
| `Storage.Initialization` | enum | Yes (nested in Storage) | Copyable, Sendable, Equatable | Correct |
| `Storage.Heap.Header` | struct | Yes (nested in Heap) | Copyable, Sendable | Correct |
| `Storage.Split.Header` | struct | Yes (nested in Split) | Copyable, Sendable | Correct |
| `Storage.Arena.Meta` | struct | N/A | @frozen BitwiseCopyable | Correct |
| `Storage.Error` | enum | Yes | Copyable, Hashable, Sendable | Correct |
| `Storage.Pool.Error` | enum | Yes | Copyable, Hashable, Sendable | Correct |
| Tag types (Initialize, Deinitialize, Move, Copy) | enums | Yes | Copyable | Correct |

**Finding**: All type declarations correctly support ~Copyable elements. No type unnecessarily forces `Element: Copyable` at the declaration level. The three inline struct types (`Inline`, `Pool.Inline`, `Arena.Inline`) are correctly ~Copyable themselves because their `@_rawLayout _Raw` stored property is structurally non-copyable.

**Structural limitation**: The inline structs cannot be conditionally Copyable (`extension Storage.Inline: Copyable where Element: Copyable`) because `@_rawLayout` types are always ~Copyable. This is a Swift compiler constraint, not a design flaw.

### Comparative Analysis 2: Extension Constraints (Core Operations)

Every extension across all disciplines is assessed for whether its `where` clause is maximally permissive.

#### Storage.Heap

| API | Current Constraint | Could Be ~Copyable? | Status |
|-----|--------------------|---------------------|--------|
| `create(minimumCapacity:)` | ~Copyable | — | OK |
| `initialization`, `slotCapacity`, `isEmpty` | ~Copyable | — | OK |
| `pointer(at:)` (mutable) | ~Copyable | — | OK |
| `pointer(at:)` (immutable) | ~Copyable | — | OK |
| `initialize` accessor + `callAsFunction(to:at:)` | ~Copyable | — | OK |
| `initialize.next(to:)` | ~Copyable | — | OK |
| `move` accessor + `callAsFunction(at:)` | ~Copyable | — | OK |
| `move(range:to:at:)` | ~Copyable | — | OK |
| `move.last()` | ~Copyable | — | OK |
| `deinitialize` accessor + `all()` | ~Copyable | — | OK |
| `deinitialize(at:)` | ~Copyable | — | OK |
| `span` property | ~Copyable | — | OK |
| `withUnsafeBufferPointer` | ~Copyable (via protocol) | — | OK |
| `copy` accessor + methods | Copyable | No (copy requires Copyable) | OK |
| `withSpan(range:body:)` | Copyable | **Yes** | **GAP** (Tier 2) |
| `withMutableSpan(range:body:)` | Copyable | **Yes** | **GAP** (Tier 2) |
| `withMutableSpan(body:)` | Copyable | **Yes** | **GAP** (Tier 1 substitute) |
| `withUnsafeMutableBufferPointer` | Copyable | Yes, but not recommended | OK (Tier 3, C interop) |

#### Storage.Inline

| API | Current Constraint | Could Be ~Copyable? | Status |
|-----|--------------------|---------------------|--------|
| `isEmpty`, `slotCapacity`, `initialization` | ~Copyable | — | OK |
| `pointer(at:)` | ~Copyable | — | OK |
| `initialize` accessor + `callAsFunction(to:at:)` | ~Copyable | — | OK |
| `initialize.next(to:)` | ~Copyable | — | OK |
| `move` accessor + `callAsFunction(at:)` | ~Copyable | — | OK |
| `move(range:to:at:)` | ~Copyable | — | OK |
| `move.last()` | ~Copyable | — | OK |
| `deinitialize` accessor + `callAsFunction(at:)` | ~Copyable | — | OK |
| `deinitialize(range:)` | ~Copyable | — | OK |
| `deinitialize.all()` | ~Copyable | — | OK |
| `span` property | ~Copyable | — | OK |
| `mutableSpan` property | ~Copyable | — | OK |
| `withUnsafeBufferPointer` | ~Copyable (via protocol) | — | OK |
| `copy(range:to:)`, `copy(to:)` | Copyable | No (copy requires Copyable) | OK |
| `withSpan(range:body:)` | Copyable | **Yes** | **GAP** (Tier 2) |
| `withMutableSpan(range:body:)` | Copyable | **Yes** | **GAP** (Tier 2) |
| `withUnsafeMutableBufferPointer` | Copyable | Yes, but not recommended | OK (Tier 3, C interop) |

#### Storage.Split

| API | Current Constraint | Could Be ~Copyable? | Status |
|-----|--------------------|---------------------|--------|
| Layout computation, factory, properties | ~Copyable | — | OK |
| `laneField`, `elementField` | ~Copyable | — | OK |
| `pointer(field:at:)` mutable + immutable | ~Copyable | — | OK |
| `subscript[field, at:]` | ~Copyable (Element), Copyable (Value) | No (subscript get returns by value) | OK |
| `fill(field:with:)` | ~Copyable (Element), Copyable (Value) | No (repeating init) | OK |
| `withPointer`, `withMutablePointer` | ~Copyable (Element), Copyable (Value) | No (pointer to Copyable field) | OK |
| `create(capacity:laneInitial:)` | ~Copyable, Lane: Copyable | — | OK |
| `initialize` accessor + `callAsFunction` | ~Copyable | — | OK |
| `move` accessor + `callAsFunction` | ~Copyable | — | OK |
| `deinitialize` accessor + `callAsFunction` | ~Copyable | — | OK |

**No gaps in Split.** All extension constraints are maximally permissive.

#### Storage.Pool

| API | Current Constraint | Could Be ~Copyable? | Status |
|-----|--------------------|---------------------|--------|
| `pointer(at:)` mutable + immutable | ~Copyable | — | OK |
| `capacity`, `allocated`, `available`, `isExhausted`, `isEmpty` | ~Copyable | — | OK |
| `allocate()` | ~Copyable | — | OK |
| `deallocate(at:)` | ~Copyable | — | OK |
| `deinitialize` accessor + `all()` | ~Copyable | — | OK |
| `copy()` | Copyable | No (deep copy requires Copyable) | OK |

**No gaps in Pool.** All constraints are maximally permissive.

#### Storage.Pool.Inline

| API | Current Constraint | Could Be ~Copyable? | Status |
|-----|--------------------|---------------------|--------|
| Properties (slotCapacity, allocated, etc.) | ~Copyable | — | OK |
| `pointer(at:)` mutable + immutable | ~Copyable | — | OK |
| `allocate()` | ~Copyable | — | OK |
| `deallocate(at:)` | ~Copyable | — | OK |
| `deinitialize` accessor + `all()` | ~Copyable | — | OK |
| *No Copyable-gated APIs at all* | — | — | **See CA4** |

#### Storage.Arena

| API | Current Constraint | Could Be ~Copyable? | Status |
|-----|--------------------|---------------------|--------|
| `init(minimumCapacity:)` | ~Copyable | — | OK |
| `slotCapacity`, `highWater` | ~Copyable | — | OK |
| `initialize(to:at:)` | ~Copyable | — | OK |
| `move(at:)` | ~Copyable | — | OK |
| `deinitialize(at:)` | ~Copyable | — | OK |
| *No Copyable-gated APIs at all* | — | — | **See CA4** |

#### Storage.Arena.Inline

| API | Current Constraint | Could Be ~Copyable? | Status |
|-----|--------------------|---------------------|--------|
| Properties (slotCapacity, allocated, etc.) | ~Copyable | — | OK |
| `pointer(at:)` mutable + immutable | ~Copyable | — | OK |
| `allocate()` | ~Copyable | — | OK |
| `unallocate(_:)` | ~Copyable | — | OK |
| `deinitialize` accessor + `all()` | ~Copyable | — | OK |
| *No Copyable-gated APIs at all* | — | — | **See CA4** |

### Comparative Analysis 3: Access Hierarchy and Gap Classification

The storage package follows a three-tier access hierarchy:

```
Tier 1 (Canonical):   var span / var mutableSpan     — property-based, safe, lifetime-annotated
Tier 2 (Secondary):   withSpan(range:) etc.           — closure-based, for when property form is impossible
Tier 3 (C interop):   with*BufferPointer              — unsafe, for C functions lacking lifetime annotations
```

**Design rule**: Tier 1 is the primary API. Tier 2 exists only when the property form cannot express the access pattern (e.g., non-linear ranges, class types lacking `mutating get`). Tier 3 exists solely for C interop.

#### Current State

| API | Tier | Heap | Inline | Constraint | ~Copyable? | Assessment |
|-----|------|------|--------|-----------|------------|------------|
| `var span` | 1 | Yes | Yes | ~Copyable | Yes | Correct |
| `var mutableSpan` | 1 | N/A (class) | Yes | ~Copyable | Yes | Correct |
| `withMutableSpan(body:)` | 1* | Yes | N/A | Copyable | **No** | **GAP** |
| `withSpan(range:body:)` | 2 | Yes | Yes | Copyable | **No** | **GAP** |
| `withMutableSpan(range:body:)` | 2 | Yes | Yes | Copyable | **No** | **GAP** |
| `withUnsafeBufferPointer` | 3 | Yes | Yes | ~Copyable | Yes | Correct |
| `withUnsafeMutableBufferPointer` | 3 | Yes | Yes | Copyable | **No** | Acceptable |

*Tier 1 substitute: `Heap.withMutableSpan(body:)` exists because classes cannot have `var mutableSpan` (requires `mutating get`). It is the canonical mutable access path for Heap — functionally Tier 1.

#### Gap Analysis

**GAP 1 — `Heap.withMutableSpan(body:)` is Copyable-only** (Priority: HIGH)

This is the canonical mutable span access for `Storage.Heap` — the only way to get a `MutableSpan` from a class-based storage. Gating it on `Copyable` means ~Copyable elements stored in `Heap` have no safe mutable span access at all. This is the most impactful gap.

**Why it can be relaxed**: `MutableSpan<Element>` is declared as `struct MutableSpan<Element: ~Copyable & ~Escapable>` — it explicitly supports ~Copyable. The closure receives a `MutableSpan` by inout reference; `R` is unrelated to Element's copyability.

**GAP 2 — `withSpan(range:body:)` and `withMutableSpan(range:body:)` are Copyable-only** (Priority: MEDIUM)

These are Tier 2 — secondary APIs for range-based access (e.g., ring buffer segments where `var span` can't express the access because it only covers linear 0..<count). They are less critical because the canonical `var span` property already supports ~Copyable. However, consumers with non-linear initialization (`.two` pattern) cannot use span-based access for ~Copyable elements at all.

**Why they can be relaxed**: Same reasoning as GAP 1 — `Span<Element: ~Copyable & ~Escapable>` and `MutableSpan<Element: ~Copyable & ~Escapable>` both accept ~Copyable.

**NOT A GAP — `withUnsafeMutableBufferPointer` stays Copyable** (Priority: NONE)

This is Tier 3 — C interop. C functions operate on trivially-copyable data. While `UnsafeMutableBufferPointer<Element>` does not structurally require `Element: Copyable` in the standard library, constraining C interop methods to `Copyable` is a reasonable safety boundary: it prevents accidentally passing ~Copyable elements to C functions that would not respect ownership. The read-only counterpart (`withUnsafeBufferPointer`) is ~Copyable because borrowing is safe regardless of copyability.

**Risk for GAP 1 and GAP 2**: Swift compiler bugs with ~Copyable elements in closure contexts. **Mitigation**: Validate with experiment before implementing.

### Comparative Analysis 4: Missing Copyable Convenience APIs

Types that have NO Copyable-gated convenience methods, where they would be natural:

| Type | Missing API | Rationale |
|------|------------|-----------|
| `Pool.Inline` | `copy() -> Pool.Inline` or deep copy mechanism | Parity with `Pool.copy()` — but Pool.Inline is ~Copyable (value type), so a `copy()` would need to return a new instance, which may require a different approach |
| `Arena` | `span` property, `withSpan`, `copy` | Arena uses slot-based access (not linear), so contiguous span is not semantically meaningful — **justified omission** |
| `Arena.Inline` | `span` property, `withSpan`, `copy` | Same as Arena — allocation is non-linear, span doesn't apply — **justified omission** |

**Finding**: The Arena and Arena.Inline omissions are architecturally justified. Pool allocators use scattered slots, not contiguous ranges, so Span access is inappropriate. Only Pool.Inline lacks a Copyable deep-copy mechanism, but its ~Copyable nature makes this complex.

### Comparative Analysis 5: Sendable Conformances

| Type | Conditional Sendable | Status |
|------|---------------------|--------|
| `Storage.Heap` | Not declared (inherits from ManagedBuffer) | **See note** |
| `Storage.Inline` | `@unchecked Sendable where Element: Sendable` | OK |
| `Storage.Split` | Not declared (inherits from ManagedBuffer) | **See note** |
| `Storage.Pool` | `@unchecked Sendable where Element: Sendable` | OK |
| `Storage.Pool.Inline` | `@unchecked Sendable where Element: Sendable` | OK |
| `Storage.Arena` | `@unchecked Sendable where Element: Sendable` | OK |
| `Storage.Arena.Inline` | `@unchecked Sendable where Element: Sendable` | OK |
| `Storage.Inline._Raw` | `@unchecked Sendable where Element: Sendable` | OK |
| `Storage.Pool.Inline._Raw` | `@unchecked Sendable where Element: Sendable` | OK |
| `Storage.Arena.Inline._Raw` | `@unchecked Sendable where Element: Sendable` | OK |
| `Storage.Initialization` | Unconditional Sendable (via declaration) | OK |
| `Storage.Error` | Unconditional Sendable | OK |
| `Storage.Pool.Error` | Unconditional Sendable | OK |
| `Storage.Heap.Header` | Unconditional Sendable | OK |
| `Storage.Split.Header` | Unconditional Sendable | OK |
| `Storage.Arena.Meta` | BitwiseCopyable (implies Sendable) | OK |
| `Storage.Field<Value>` | Unconditional Sendable | OK |

**Note on ManagedBuffer subclasses**: `Storage.Heap` and `Storage.Split` inherit from `ManagedBuffer`, which is `@unchecked Sendable`. This means they are unconditionally Sendable at the type level, regardless of `Element`. This is a known ManagedBuffer design issue — the types are safe in practice because element access requires pointer operations that the caller must synchronize.

### Comparative Analysis 6: Comparison with Swift Standard Library Patterns

How does swift-storage-primitives compare to the Swift standard library's ~Copyable approach?

| Aspect | Swift stdlib | swift-storage-primitives | Assessment |
|--------|-------------|--------------------------|------------|
| Generic bound on container | `Array<Element>` requires Copyable; `UnsafeBufferPointer` does not | `Storage<Element: ~Copyable>` | **Superior** — accepts ~Copyable at namespace level |
| Canonical span access | `var span` supports ~Copyable | `var span`: ~Copyable | **Correct** |
| Canonical mutable span | `var mutableSpan` supports ~Copyable | `var mutableSpan` (Inline): ~Copyable; `withMutableSpan` (Heap): Copyable only | **Gap** on Heap mutable access |
| Range-based span access | Closure-based in stdlib | Closure-based, Copyable only | **Gap** (secondary, lower priority) |
| C interop | `withUnsafeBufferPointer` ~Copyable | Read: ~Copyable; Write: Copyable | **Acceptable** — write-side Copyable is a safety boundary for C |
| Copy semantics | `Array.init(repeating:count:)` requires Copyable | Copy methods gated on Copyable | **Correct** |
| Move semantics | `UnsafeMutablePointer.move()` works with ~Copyable | All move operations: ~Copyable | **Correct** |
| Conditional Copyable | Not applicable (Array is always Copyable) | Inline types can't be Copyable (@_rawLayout) | **Compiler limitation** |

## Constraints

1. **@_rawLayout is always ~Copyable** — `Storage.Inline`, `Pool.Inline`, and `Arena.Inline` cannot gain conditional Copyable conformance until the Swift compiler supports it (no open proposal as of 2026-02).

2. **ManagedBuffer Sendable** — `Storage.Heap` and `Storage.Split` inherit unconditional `@unchecked Sendable` from `ManagedBuffer`. This cannot be narrowed without a stdlib change.

3. **Closure + ~Copyable** — While `Span<~Copyable>` is sound in principle, there may be compiler bugs when passing `Span<~Copyable>` through closures. Each relaxation should be validated with an experiment.

## Status

| Phase | Status |
|-------|--------|
| CA1: Type declarations | DONE — no gaps |
| CA2: Extension constraints (core ops) | DONE — no gaps in core ops |
| CA3: Access hierarchy gap classification | DONE — 5 gaps identified, hierarchy confirmed |
| CA4: Missing Copyable convenience APIs | DONE — no action needed |
| CA5: Sendable conformances | DONE — no gaps |
| CA6: Stdlib comparison | DONE |
| EXP: Validate `Span<~Copyable>` in closures | TODO |
| IMPL: Relax `Heap.withMutableSpan(body:)` | TODO (blocked on EXP) |
| IMPL: Relax range-based closure methods | TODO (blocked on EXP) |

## Outcome

**Status**: IN_PROGRESS — analysis complete, experiment and implementation pending

### Access Hierarchy

The canonical access pattern is property-based:

```
var span: Span<Element>                  — Tier 1, canonical read access
var mutableSpan: MutableSpan<Element>    — Tier 1, canonical write access (value types)
withMutableSpan(body:)                   — Tier 1 substitute for classes (no mutating get)
withSpan(range:body:)                    — Tier 2, only when property form can't express the pattern
withMutableSpan(range:body:)             — Tier 2, same
withUnsafeBufferPointer                  — Tier 3, C interop (read)
withUnsafeMutableBufferPointer           — Tier 3, C interop (write)
```

### Summary Score

| Discipline | ~Copyable Coverage | Gaps | Classification |
|------------|--------------------|------|----------------|
| **Heap** | Tier 1 read: OK, Tier 1 write: **GAP** | `withMutableSpan(body:)` Copyable-only | 1 high-priority gap, 2 medium |
| **Inline** | Tier 1 read: OK, Tier 1 write: OK | Range-based closures Copyable-only | 2 medium-priority gaps |
| **Split** | All OK | None | Complete |
| **Pool** | All OK | None | Complete |
| **Pool.Inline** | All OK | None | Complete |
| **Arena** | All OK | None | Complete |
| **Arena.Inline** | All OK | None | Complete |

### Recommended Actions

**Priority 1 — Relax `Heap.withMutableSpan(body:)` to ~Copyable** (1 API):

This is the canonical mutable span access for class-based storage. Its Copyable constraint blocks ~Copyable elements from any safe mutable span access on Heap. Requires experiment to validate.

| File | API | Change |
|------|-----|--------|
| `Storage.Heap+Memory.Contiguous.Protocol.swift` | `withMutableSpan(body:)` | Move to `where Element: ~Copyable` extension |

**Priority 2 — Relax range-based closure access to ~Copyable** (4 APIs):

These are Tier 2 (secondary) — they serve non-linear access patterns (ring buffer segments). Lower priority because the canonical `var span` property already supports ~Copyable. Requires experiment to validate.

| File | API | Change |
|------|-----|--------|
| `Storage.Heap Copyable.swift` | `withSpan(range:body:)` | Move to `~Copyable` extension |
| `Storage.Heap Copyable.swift` | `withMutableSpan(range:body:)` | Move to `~Copyable` extension |
| `Storage.Inline Copyable.swift` | `withSpan(range:body:)` | Move to `~Copyable` extension |
| `Storage.Inline Copyable.swift` | `withMutableSpan(range:body:)` | Move to `~Copyable` extension |

**No action — C interop methods stay Copyable** (2 APIs):

`withUnsafeMutableBufferPointer` on Heap and Inline is Tier 3 (C interop). Keeping these Copyable-gated is a reasonable safety boundary — C functions do not respect Swift ownership semantics. The read-only counterpart `withUnsafeBufferPointer` is already ~Copyable because borrowing is safe regardless.

**No action — Pool, Arena, and inline variants**:

Pool allocators use scattered slots (not contiguous ranges), so Span-based access is semantically inappropriate. Arena allocation is non-linear. No Copyable convenience APIs are missing.

**Monitor — Conditional Copyable for `@_rawLayout`**:

`Storage.Inline`, `Pool.Inline`, and `Arena.Inline` cannot be conditionally Copyable until the Swift compiler supports conditional Copyable for `@_rawLayout` types. No action until a Swift Evolution proposal lands.

### Not Recommended

- Adding `copy()` to `Pool.Inline` or `Arena.Inline` — These are ~Copyable value types. Deep copy is better expressed at the buffer layer (the consumer) rather than the storage layer.
- Adding span/copy to `Arena` or `Arena.Inline` — Non-linear allocation makes contiguous Span access semantically incorrect.
- Relaxing `withUnsafeMutableBufferPointer` to ~Copyable — C interop boundary should enforce Copyable as a safety guard against passing move-only values to C functions.

## References

- Storage.swift:780-782 — Comment documenting @_rawLayout Copyable limitation
- [MEM-COPY-*] memory skill — Ownership and copyability rules
- [COPY-FIX-*] copyable-remediation skill — Constraint propagation fixes
- swiftlang/swift#86652 — Deinit workaround for cross-module ~Copyable structs

---

## Deferral

**Date**: 2026-03-15
**Previous status**: IN_PROGRESS (since 2026-02-12)
**New status**: DEFERRED

**Blocker/Reason**: All 6 comparative analyses are complete. Two action items remain: (1) validate Span<~Copyable> in closures via experiment, and (2) relax Heap.withMutableSpan(body:) and range-based closure methods to ~Copyable. Both are blocked on the experiment (EXP phase), which has not been run. The analysis identified 1 high-priority gap (Heap mutable span access) and 4 medium-priority gaps (range-based closure access). Deferred because the experiment requires focused compiler-interaction time and the gaps have not been blocking in practice.

**Resumption trigger**: When a downstream consumer needs ~Copyable mutable span access on Storage.Heap, or when Swift compiler ~Copyable-in-closures support is verified stable.
