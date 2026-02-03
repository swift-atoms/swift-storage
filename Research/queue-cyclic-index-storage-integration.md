# Queue Cyclic-Index and Storage Integration

<!--
---
version: 1.0.0
last_updated: 2026-01-29
status: IN_PROGRESS
scope: primitives-wide
packages: [queue-primitives, cyclic-index-primitives, storage-primitives]
---
-->

## Context

This research explores the integration opportunities between three primitives packages:

| Package | Tier | Current Role |
|---------|------|--------------|
| `swift-cyclic-index-primitives` | 9 (Ranges) | Phantom-typed cyclic indices using `Cyclic.Group<N>.Element` |
| `swift-queue-primitives` | 13 (Dimension) | Ring buffer queues with inline `Queue.Storage` and `Queue.Storage.Inline` |
| `swift-storage-primitives` | 12 (Containers) | Generic storage abstractions including `Storage.Ring.Header` |

**Trigger** [RES-012]: Proactive architecture review to improve consistency and identify extraction opportunities.

**Goals**:
1. Evaluate whether `Queue` should use `Index<T>.Cyclic<N>` for ring buffer indexing
2. Evaluate extracting `Queue.Storage` to `storage-primitives`
3. Document architectural trade-offs and constraints

---

## Question 1: Queue + Cyclic-Index Integration

**Question**: Should `Queue<Element>` use `Index<Element>.Cyclic<N>` from cyclic-index-primitives for its ring buffer index arithmetic?

### Current State

**Queue's Ring Buffer Indexing** (queue-primitives, Tier 13):
```swift
// Queue.swift:92-96
package struct Header {
    package var head: Index_Primitives.Index<Element>
    package var tail: Index_Primitives.Index<Element>
    package var count: Index_Primitives.Index<Element>.Count
}

// Dynamic wrapping via manual modulo:
physicalIndex = (physicalIndex + 1) % capacity  // Manual Int arithmetic
```

**Cyclic Index API** (cyclic-index-primitives, Tier 9):
```swift
// Index.Cyclic.swift
public typealias Cyclic<let N: Int> = Tagged<Tag, Cyclic_Primitives.Cyclic.Group<N>.Element>

// Automatic wrapping via group arithmetic:
index += .one  // Wraps automatically at N boundary
```

### Analysis

#### Option A: Adopt `Index<Element>.Cyclic<N>` in Queue

**Description**: Replace `Index<Element>` with `Index<Element>.Cyclic<N>` for head/tail tracking.

**Advantages**:
- **Type-enforced wrapping**: Arithmetic automatically wraps within [0, N)
- **No manual modulo**: Eliminates `% capacity` patterns throughout queue code
- **Semantic clarity**: Type communicates "this is a cyclic index"
- **Phantom type safety**: Prevents mixing indices from different queues

**Disadvantages**:
- **Compile-time capacity constraint**: Cyclic<N> requires N as value generic
- **Incompatible with dynamic capacity**: Queue grows dynamically; N would need to change
- **Tier inversion**: queue-primitives (Tier 13) cannot depend on cyclic-index-primitives (Tier 9) without creating upward dependency

**Feasibility Analysis**:

The fundamental issue is that `Queue` has **dynamic capacity** but `Index.Cyclic<N>` requires **compile-time capacity**.

```swift
// Queue grows capacity at runtime:
if count == capacity {
    let newCapacity = max(4, capacity * 2)  // Runtime decision
    // Head/tail indices must be recalculated for new capacity
}

// Cyclic<N> has fixed capacity:
var index: Index<Element>.Cyclic<8>  // Fixed at 8
// Cannot become Cyclic<16> when queue grows
```

This is a **fundamental mismatch**: cyclic indices solve a different problem (statically-known ring buffer size) than Queue needs (dynamically-growing ring buffer).

**Verdict**: **Not viable for dynamic Queue variants**.

#### Option B: Adopt Cyclic Index for `Queue.Static<N>`

**Description**: Use `Index<Element>.Cyclic<N>` specifically for the `Queue.Static<let capacity: Int>` variant.

**Advantages**:
- **Capacity is compile-time**: Static variant has `<let capacity: Int>` matching `<let N: Int>`
- **Perfect semantic fit**: Both describe fixed-size cyclic structures
- **Eliminates manual modulo**: In `Queue.Static`, wrapping would be automatic

**Disadvantages**:
- **Tier dependency**: Would require queue-primitives → cyclic-index-primitives dependency
- **Current tier mismatch**: Queue (Tier 13) > Cyclic-Index (Tier 9)
- **Code divergence**: Static variant would use different index type than other variants

**Tier Dependency Impact**:

Adding cyclic-index-primitives as a dependency is **valid** (downward from 13 to 9):

```swift
// Package.swift change would be valid:
dependencies: [
    .package(path: "../swift-cyclic-index-primitives"),  // Tier 9 ✓
    // ... existing dependencies
]
```

However, this adds a dependency for a single variant. The benefit-to-coupling ratio is low.

**Verdict**: **Technically viable but weak justification**.

#### Option C: Keep Current Design (Manual Wrapping)

**Description**: Retain current `Index<Element>` + manual modulo arithmetic.

**Advantages**:
- **No new dependencies**: Keeps queue-primitives self-contained
- **Uniform implementation**: All variants use same index type
- **Runtime flexibility**: Works with dynamic capacity
- **storage-primitives alignment**: Already provides `Storage.Ring.successor/predecessor`

**Disadvantages**:
- **Manual modulo**: Continues `% capacity` patterns
- **No type-level wrapping guarantee**: Wrapping is behavioral, not structural

**Verdict**: **Current best fit for dynamic variants**.

### Comparison Table

| Criterion | Option A: Cyclic<N> All | Option B: Cyclic<N> Static | Option C: Keep Current |
|-----------|-------------------------|---------------------------|------------------------|
| Dynamic variants | ❌ Impossible | N/A | ✓ Works |
| Static variant | ❌ Impossible | ✓ Good fit | ✓ Works |
| Dependencies | +1 (cyclic-index) | +1 (cyclic-index) | No change |
| Code uniformity | N/A | ❌ Divergent | ✓ Uniform |
| Implementation effort | N/A | Medium | None |

### Recommendation

**Status**: RECOMMENDATION

**Recommendation**: **Keep current design (Option C)** for all Queue variants.

**Rationale**:
1. **Dynamic variants are primary**: Most Queue users need unbounded growth
2. **Weak justification for Static**: Adding a dependency for one variant is poor coupling hygiene
3. **storage-primitives provides helpers**: `Storage.Ring.successor/predecessor` already abstracts wrapping logic
4. **Type safety achieved differently**: `Index<Element>` phantom type provides cross-collection safety without cyclic arithmetic

**Future consideration**: If a future `Cyclic.Ring<N>` type emerges for fixed-size-only ring buffers, it could leverage cyclic-index-primitives. Queue is not that type.

---

## Question 2: Queue.Storage Extraction to storage-primitives

**Question**: Should `Queue.Storage` and `Queue.Storage.Inline` be extracted to storage-primitives?

### Current State

**Queue's Storage Types** (queue-primitives, Tier 13):
```swift
// Queue.swift - Nested inside Queue for ~Copyable propagation
package final class Storage: ManagedBuffer<Header, Element> { ... }

// Queue.Storage.Inline.swift - Nested extension
package struct Inline<let capacity: Int>: ~Copyable {
    package var raw: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>
    // Ring buffer operations: initialize, move, deinitialize, linearize
}
```

**Storage-Primitives Types** (storage-primitives, Tier 12):
```swift
// Storage.swift - Generic heap storage
public final class Storage<Element: ~Copyable>: ManagedBuffer<Int, Element> { ... }

// Storage.Inline.swift - Generic inline storage (64-byte slots)
public struct Inline<let capacity: Int>: ~Copyable { ... }

// Storage.Ring.swift - Ring buffer operations (static methods)
public static func successor(of:wrapping:) -> Index<Element>
public static func linearize(from:head:count:capacity:to:)

// Storage.Heap.Header.Ring.swift - Ring buffer header
public struct Header { head, tail, count }
```

### Analysis

#### Option A: Full Extraction of Queue.Storage

**Description**: Move `Queue.Storage` class to storage-primitives, making it `Storage<Element>.Ring` or similar.

**Advantages**:
- **Reusability**: Other ring buffer types (Deque is separate but similar) could share
- **storage-primitives completeness**: Ring buffer storage as first-class primitive
- **Reduced duplication**: Single source for ring buffer storage logic

**Disadvantages**:
- **~Copyable constraint propagation**: `Queue.Storage` MUST be nested inside `Queue` to inherit Element's ~Copyable suppression. Moving it external breaks this.
- **Tier inversion**: queue-primitives (13) would depend on storage-primitives (12) - valid direction BUT...
- **Current workaround exists**: Queue already has nested Storage precisely because external doesn't work

**Constraint Analysis**:

The fundamental blocker is **[MEM-COPY-006] Category 3**:

```swift
// This FAILS due to ~Copyable constraint propagation bug:
// External storage class
public final class RingStorage<Element: ~Copyable>: ManagedBuffer<...> { }

// Usage in Queue
public struct Queue<Element: ~Copyable>: ~Copyable {
    var _storage: RingStorage<Element>  // Element implicitly Copyable here!
}
```

The Swift compiler does not propagate `~Copyable` suppression to external generic types, even when they declare `Element: ~Copyable`. This is documented in the Collection Primitives Architecture research:

> **Bug 1: Extension Declaration Site**
> Nested type doesn't inherit ~Copyable when declared in extension or external module.

**Verdict**: **Not viable** until Swift compiler fixes ~Copyable propagation.

#### Option B: Extract Queue.Storage.Inline Only

**Description**: Extract `Queue.Storage.Inline<N>` to storage-primitives since it's a struct (not class).

**Advantages**:
- **Struct semantics**: Inline storage doesn't have the same reference-type constraint issues
- **Reusability**: `Queue.Static`, `Queue.Small`, `Queue.DoubleEnded.Static` all use similar inline storage

**Disadvantages**:
- **Same ~Copyable issue**: Inline<N> stores Element, hits same propagation bug
- **Ring buffer specialization**: Queue.Storage.Inline has ring-buffer-specific methods (deinitialize from head with wrapping) that differ from Storage.Inline

**Comparative API**:

| Operation | Queue.Storage.Inline | storage-primitives Storage.Inline |
|-----------|---------------------|----------------------------------|
| Slot size | 64 bytes | 64 bytes |
| Deinit | `deinitialize(from:count:)` ring-aware | `deinitialize(count:)` linear |
| Linearize | `linearize(to:from:count:)` | N/A (not ring-aware) |
| Copy | `copy(to:from:count:)` | `copy(to:count:)` |

The ring buffer awareness is intrinsic to Queue's inline storage. Extracting would either:
1. Generalize storage-primitives' Inline to support ring semantics (scope creep)
2. Leave Queue with its own specialized version (no benefit)

**Verdict**: **Not viable** - same constraint + specialization issues.

#### Option C: Extract Ring Buffer Operations Only

**Description**: Keep `Queue.Storage` nested but delegate to `Storage.Ring` operations from storage-primitives.

**Current state**: This is **already partially done**:

storage-primitives provides:
- `Storage.Ring.successor(of:wrapping:)`
- `Storage.Ring.predecessor(of:wrapping:)`
- `Storage.Ring.physicalIndex(forLogical:head:capacity:)`
- `Storage.Ring.linearize(from:head:count:capacity:to:)`
- `Storage.Ring.deinitialize(_:head:count:capacity:)`
- `Storage.Ring.Header` (head, tail, count)

Queue could delegate to these instead of reimplementing.

**Advantages**:
- **No ~Copyable issues**: Uses static methods with explicit parameters
- **Partial implementation exists**: storage-primitives already has the operations
- **Header unification**: `Storage.Ring.Header` matches Queue's Header semantics

**Disadvantages**:
- **Dependency direction**: queue-primitives (13) would need storage-primitives (12) as dependency
- **API translation**: Queue uses `Int` indices internally; Storage.Ring uses `Index<Element>`
- **Limited benefit**: Most of the code is in the nested Storage class anyway

**Tier Dependency Validation**:

Adding storage-primitives as a dependency to queue-primitives is **valid** (downward: 13 → 12):

```swift
// This would be a valid Package.swift change:
dependencies: [
    .package(path: "../swift-storage-primitives"),  // Tier 12 ✓
    // ... existing
]
```

**Implementation Gap Analysis**:

| Queue Operation | storage-primitives Equivalent | Match |
|-----------------|------------------------------|-------|
| `_storage._initializeElement(at:to:)` | `storage.initialize(to:at:)` | ✓ |
| `_storage._moveElement(at:)` | `storage.move(at:)` | ✓ |
| Manual modulo wrap | `Storage.Ring.successor(of:wrapping:)` | ✓ |
| `_storage.deinit` (ring cleanup) | `Storage.Ring.deinitialize(...)` | ✓ |
| `Queue.Storage.Inline.linearize` | `Storage.Ring.linearize(...)` | Partial (different types) |
| `Queue.Header` | `Storage.Ring.Header` | Semantically equivalent |

**Verdict**: **Viable but limited benefit** given existing implementation.

#### Option D: Keep Current Separation

**Description**: Maintain Queue.Storage as nested type, no extraction.

**Advantages**:
- **~Copyable works**: Nested declaration solves constraint propagation
- **Self-contained**: Queue package has no additional dependencies
- **Documented pattern**: Collection Primitives Architecture documents this as the canonical approach

**Disadvantages**:
- **Duplication**: Similar ring buffer logic in queue-primitives and storage-primitives
- **Maintenance burden**: Bug fixes need application in multiple places

**Verdict**: **Current best option** given compiler constraints.

### Comparison Table

| Criterion | A: Full Extraction | B: Inline Only | C: Operations Only | D: Keep Current |
|-----------|-------------------|----------------|-------------------|-----------------|
| ~Copyable support | ❌ Broken | ❌ Broken | ✓ Works | ✓ Works |
| New dependencies | +1 | +1 | +1 | None |
| Code reuse | High | Medium | Low | None |
| Implementation | Blocked | Blocked | Possible | Already done |
| Maintenance | Better | Neutral | Neutral | Current |

### Recommendation

**Status**: RECOMMENDATION

**Recommendation**: **Keep current nested Storage design (Option D)**.

**Rationale**:
1. **Compiler constraint is blocking**: ~Copyable propagation bug prevents extraction
2. **Documentation captures rationale**: Collection Primitives Architecture already documents why nesting is required
3. **storage-primitives serves different role**: Its Storage is for general-purpose heap allocation; Queue.Storage is ring-buffer-specialized

**Future consideration**: When Swift fixes ~Copyable constraint propagation (tracked as part of ongoing noncopyable generics work), revisit extraction. Until then, nesting is the only working approach.

---

## Question 3: Header Type Unification

**Question**: Should Queue use `Storage.Ring.Header` from storage-primitives instead of its own `Queue.Header`?

### Current State

**Queue.Header** (queue-primitives):
```swift
package struct Header {
    package var head: Index_Primitives.Index<Element>
    package var tail: Index_Primitives.Index<Element>
    package var count: Index_Primitives.Index<Element>.Count
}
```

**Storage.Ring.Header** (storage-primitives):
```swift
public struct Header: ~Copyable, Sendable {
    public var head: Index<Element>
    public var tail: Index<Element>
    public var count: Index<Element>.Count

    // Convenience methods:
    public mutating func advanceHead(capacity:)
    public mutating func advanceTail(capacity:)
    public mutating func retreatHead(capacity:)
    public mutating func retreatTail(capacity:)
}
```

### Analysis

These types are **semantically identical** but differ in:

| Aspect | Queue.Header | Storage.Ring.Header |
|--------|--------------|---------------------|
| Visibility | `package` | `public` |
| Conformances | None | `~Copyable, Sendable` |
| Convenience methods | None | advance/retreat operations |
| Generic context | Inside `Queue<Element>` | Inside `Storage<Element>.Ring` |

**Unification Challenge**:

Using `Storage.Ring.Header` inside `Queue.Storage` class (which is `ManagedBuffer<Header, Element>`) would require:

```swift
// Queue.Storage declaration would become:
final class Storage: ManagedBuffer<Storage_Primitives.Storage<Element>.Ring.Header, Element>
```

**Issues**:
1. The `Storage<Element>` from storage-primitives has a **different Element generic** than the nested Storage in Queue
2. Would need to use external Storage's namespace, creating coupling
3. ManagedBuffer requires the Header type; we'd be depending on external type's layout

**Verdict**: **Not worth the coupling complexity** for identical semantics.

### Recommendation

**Status**: RECOMMENDATION

**Recommendation**: **Keep Queue.Header as separate type**.

**Rationale**: The duplication is intentional isolation. Queue's Header is internal implementation detail; changing it doesn't affect API. The cost of depending on external Header exceeds benefit.

---

## Summary

| Question | Recommendation | Rationale |
|----------|---------------|-----------|
| Cyclic-Index integration | **No** | Dynamic capacity incompatible with compile-time N |
| Queue.Storage extraction | **No** | ~Copyable propagation bug blocks external storage |
| Header unification | **No** | Coupling cost exceeds benefit |

### Constraints Encountered

1. **[MEM-COPY-006] Category 3**: ~Copyable constraint propagation requires nested type declarations
2. **Dynamic vs Static capacity**: Queue's dynamic growth is fundamentally incompatible with cyclic indices
3. **Tier dependencies**: While tier order permits queue → storage dependency, the benefit doesn't justify coupling

### Patterns Validated

1. **Nested Storage Class Pattern**: Confirmed as necessary per Collection Primitives Architecture
2. **Manual Ring Buffer Arithmetic**: Appropriate for dynamic-capacity ring buffers
3. **Package Isolation**: Queue-primitives' self-containment is the correct design given current Swift limitations

---

## References

- Collection Primitives Architecture.md (queue-primitives Research)
- Primitives Tiers.md (swift-primitives Documentation)
- [MEM-COPY-006] ~Copyable constraint propagation (memory skill)
- SE-0390: Noncopyable structs and enums
- SE-0427: Noncopyable generics

---

*Swift Primitives - Primitives-Wide Research*
*Document Version: 1.0.0*
*Date: 2026-01-29*
