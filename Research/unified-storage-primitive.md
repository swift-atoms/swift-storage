# Unified Storage Primitive Feasibility

<!--
---
version: 1.0.0
last_updated: 2026-01-29
status: RECOMMENDATION
tier: 2
---
-->

## Context

Hash.Table compilation broke due to Index_Primitives API changes. Before fixing, we're investigating whether Hash.Table should adopt the new storage model from array-primitives, and whether a single unified storage primitive could serve Queue, Stack, and Hash.Table.

**Trigger**: [RES-001] Design decision requiring systematic analysis of alternatives.

**Scope**: Cross-package (swift-storage-primitives, swift-array-primitives, swift-queue-primitives, swift-stack-primitives, swift-hash-table-primitives).

## Question

Can a unified storage primitive work for all of Queue, Stack, and Hash.Table?

## Analysis

### Current Storage Implementations

| Data Structure | Header Type | Element Type | Layout | Access Pattern |
|----------------|-------------|--------------|--------|----------------|
| **Array** | `Int` (count) | `Element` | Contiguous | Linear indexing |
| **Queue** | `(head, tail, count)` | `Element` | Ring buffer | Modulo arithmetic |
| **Stack** | `Int` (count) | `Element` | Contiguous | Linear indexing |
| **Hash.Table** | `(count, occupied, hashCapacity)` | `Int` (raw) | Block split `[hashes...][positions...]` | Bucket probing |

### Option A: Fully Unified Storage

Create a single `Storage<Element, Header>` that all data structures use.

**Implementation**:
```swift
public final class Storage<Element: ~Copyable, Header>: ManagedBuffer<Header, Element> {
    // Generic header type
    // Shared allocation/deallocation
    // Common element access methods
}
```

**Advantages**:
- Single allocation implementation
- Consistent CoW semantics
- Shared inline storage pattern
- Reduced code duplication

**Disadvantages**:
- Header type explosion (each structure needs different header)
- Hash.Table stores `Int` pairs, not `Element` - fundamentally different
- Ring buffer operations (Queue) require specialized methods
- Block-split layout (Hash.Table) incompatible with contiguous element storage
- Complexity cost outweighs benefits

**Verdict**: ❌ Not viable. Hash.Table's requirements are fundamentally incompatible.

### Option B: Storage Primitives as Base Layer

Use `Storage_Primitives.Storage.Dynamic<Element>` with its current `Int` header for Array/Stack, and keep separate implementations for Queue (ring buffer) and Hash.Table (block-split).

**Current Storage Primitives Design**:
```swift
// From swift-storage-primitives
public final class Storage<Element: ~Copyable>: ManagedBuffer<Int, Element>

// Header types (separate structs, not ManagedBuffer headers):
extension Storage.Heap.Header {
    struct Count { var count: Index<Element>.Count }
    struct Ring { var head, tail: Index<Element>; var count: Index<Element>.Count }
    struct Arena { var head, tail, freeHead: Index<Element>; var count, capacity: Index<Element>.Count }
}
```

**Current Array-Primitives Usage**:
```swift
// Array uses Storage<Element> directly
package typealias Storage = Storage_Primitives.Storage.Dynamic<Element>
```

**Applicability**:

| Structure | Can Use Storage<Element>? | Notes |
|-----------|---------------------------|-------|
| Array | ✅ Yes | Already does |
| Stack | ✅ Yes | Linear, count-only header matches |
| Queue | ⚠️ Partial | Ring header needs (head, tail, count) - stored separately |
| Hash.Table | ❌ No | Stores `Int` pairs, not `Element`; needs triple header |

**Verdict**: ⚠️ Partially viable. Stack could migrate; Queue/Hash.Table cannot directly use it.

### Option C: Layered Approach (Recommended)

Maintain three categories:

1. **Storage<Element>** - For contiguous typed element storage (Array, Stack)
2. **Storage<Element>.Ring** - Ring buffer operations (static methods, used by Queue)
3. **Hash.Table.Storage** - Custom block-split storage (unique requirements)

**Rationale**:

Hash.Table is fundamentally different from the others:

| Aspect | Array/Stack/Queue | Hash.Table |
|--------|-------------------|------------|
| Element type | User's `Element` | Always `Int` (hash/position pairs) |
| Type parameter | Constrains storage | Phantom type for index safety |
| Layout | Contiguous elements | Block-split `[hashes...][positions...]` |
| Header | Count-based | Load-factor tracking (count, occupied, capacity) |
| Deinitialization | Per-element deinit | None (Int is trivial) |
| ~Copyable support | Yes, propagates | N/A (stores Int, not Element) |

**Shared Infrastructure** that CAN be unified:
- Inline 64-byte slot design
- Growth factor (2x, minimum threshold)
- Cached pointer pattern
- CoW checking utilities
- `Index<Element>` typed indexing

### Comparison Matrix

| Criterion | Option A (Fully Unified) | Option B (Storage<Element> Base) | Option C (Layered) |
|-----------|--------------------------|----------------------------------|-------------------|
| Code reuse | High | Medium | Medium |
| Complexity | Very High | Medium | Low |
| Hash.Table fit | ❌ Poor | ❌ Poor | ✅ Good |
| Queue fit | ⚠️ Awkward | ⚠️ Partial | ✅ Good |
| Stack fit | ✅ Good | ✅ Good | ✅ Good |
| Implementation effort | Very High | Medium | Low |
| Maintenance burden | High | Medium | Low |
| Type safety | Compromised | Preserved | Preserved |

## Outcome

**Status**: RECOMMENDATION

**Recommendation**: Adopt **Option C (Layered Approach)**

### Specific Actions

1. **Stack**: Migrate to use `Storage_Primitives.Storage.Dynamic<Element>` (matches Array pattern)

2. **Queue**: Keep custom `Storage` class with ring buffer header, but use:
   - `Storage.Ring` static methods for wrap arithmetic
   - `Storage.Heap.Header.Ring` struct for header state
   - Inline storage pattern from Storage Primitives

3. **Hash.Table**: Keep custom `Storage` class because:
   - Stores `Int` pairs (hashes and positions), not `Element`
   - Block-split layout `[hashes...][positions...]` is unique
   - Triple header `(count, occupied, hashCapacity)` for load factor
   - No element deinitialization needed (Int is trivial)
   - Phantom type `Element` used only for `Index<Element>` safety

4. **Shared Infrastructure**: Extract to Storage Primitives:
   - Inline 64-byte slot pattern (already exists as `Storage.Inline<N>`)
   - Growth strategy helpers
   - Cached pointer utilities

### Hash.Table Immediate Fix

The current compilation errors in Hash.Table are due to Index API changes, not storage issues. Fix by:

1. Update Index construction: `Index<Element>(__unchecked: (), Ordinal(UInt(bitPattern: rawPosition)))`
2. Update Index extraction: `Int(bitPattern: index.position.rawValue)`
3. Add helper methods for clean conversion

This is independent of storage unification and should proceed immediately.

## References

- `/Users/coen/Developer/swift-primitives/swift-storage-primitives/Sources/Storage Primitives/Storage.swift`
- `/Users/coen/Developer/swift-primitives/swift-array-primitives/Sources/Array Primitives Core/Array.swift`
- `/Users/coen/Developer/swift-primitives/swift-queue-primitives/Sources/Queue Primitives Core/Queue.swift`
- `/Users/coen/Developer/swift-primitives/swift-stack-primitives/Sources/Stack Primitives Core/Stack.swift`
- `/Users/coen/Developer/swift-primitives/swift-hash-table-primitives/Sources/Hash Table Primitives/Hash.Table.swift`
