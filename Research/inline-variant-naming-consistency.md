# Inline Variant Naming Consistency

<!--
---
version: 1.3.0
last_updated: 2026-02-03
status: CONTEXTUALLY SUPERSEDED (at storage layer)
---
-->

## Supersession Note (2026-02-03)

This decision remains valid at the **ADT layer** (Array, Set, Dictionary, Stack, Queue, etc.), where:
- `Inline` = all-N-initialized (fixed count)
- `Static` = variable count (0 to N)

However, at the **storage layer**, naming by count semantics was abandoned in favor of **placement-based naming** to align with canonical storage theory:
- `Storage.Inline` = embedded in container (placement axis)
- `Storage.Heap` = independently allocated (placement axis)

Count semantics at the storage layer are encoded by `Storage.Initialization`, not by the type name.

See: `storage-ownership-reference-synthesis.md` (Axis Ownership Policy).

---

## Context

During Dictionary.Ordered.Inline implementation, inconsistent naming across inline storage variants was identified. This affects layering decisions: should `Dictionary.Ordered.Inline` use `Set<Key>.Ordered.Static` → `Hash.Table<Key>.Inline`?

## Question

What should the consistent naming convention be for inline/static storage variants across hash-table-primitives, set-primitives, dictionary-primitives, and storage-primitives?

## Analysis

### The Array Convention (Authoritative)

Array establishes clear semantic distinction between two names:

```swift
/// Fixed-count inline array (typealias to `Swift.InlineArray`).
/// All N elements are always initialized.
public typealias Inline<let N: Int> = Swift.InlineArray<N, Element>

/// Fixed-capacity vector with inline storage (static_vector / ArrayVec).
/// Count varies from 0 to capacity.
public struct Static<let capacity: Int>: ~Copyable
```

| Name | Count Semantics | Initialization | C++ Equivalent |
|------|-----------------|----------------|----------------|
| **Inline** | Fixed (always N) | All slots initialized | `std::array<T, N>` |
| **Static** | Variable (0 to N) | Only `count` slots initialized | `static_vector<T, N>` |

### Current State Audit

| Type | Has `count` field? | Count Semantics | Current Name | Correct Name |
|------|-------------------|-----------------|--------------|--------------|
| `Array.Inline<N>` | No | Fixed (always N) | Inline | **Inline ✓** |
| `Array.Static<N>` | Yes (`count`) | Variable (0 to N) | Static | **Static ✓** |
| `Storage.Inline<N>` | No* | Variable (caller tracks) | Inline | **Static ✗** |
| `Hash.Table.Inline<N>` | Yes (`_count`) | Variable (0 to N) | Inline | **Static ✗** |
| `Set.Ordered.Static<N>` | Yes (`storedCount`) | Variable (0 to N) | Static | **Static ✓** |
| `Dictionary.Ordered.Inline<N>` | Yes | Variable (0 to N) | Inline | **Static ✗** |

*`Storage.Inline` doesn't track count internally but supports variable initialization (caller responsibility).

### The Inconsistency

Three packages use "Inline" for what should be "Static":

1. **storage-primitives**: `Storage.Inline` has variable initialization → should be `Storage.Static`
2. **hash-table-primitives**: `Hash.Table.Inline` has `_count` field → should be `Hash.Table.Static`
3. **dictionary-primitives**: `Dictionary.Ordered.Inline` has variable count → should be `Dictionary.Ordered.Static`

### Option A: Standardize on Array Convention (Recommended)

Rename all variable-count inline types to `Static`:

| Before | After |
|--------|-------|
| `Storage.Inline` | `Storage.Static` |
| `Hash.Table.Inline` | `Hash.Table.Static` |
| `Dictionary.Ordered.Inline` | `Dictionary.Ordered.Static` |

Keep `Set.Ordered.Static` as-is (already correct).

**Advantages**:
- Follows Array's authoritative convention
- "Static" = `static_vector` semantics (variable count, compile-time capacity)
- "Inline" reserved for fixed-count wrappers around `Swift.InlineArray`
- Consistent layering: `Dict.Static → Set.Static → Hash.Table.Static`

**Disadvantages**:
- Breaking change for storage, hash-table, dictionary packages
- "Static" has other meanings in Swift (static members)

### Option B: Redefine "Inline" to Include Variable-Count

Change the convention so "Inline" means any compile-time capacity inline storage.

**Advantages**:
- Fewer renames (only Set needs to change)
- "Inline" is more descriptive of storage mechanism

**Disadvantages**:
- Conflicts with Array's established convention
- Loses semantic precision (Inline vs Static distinction is valuable)
- Array.Inline is a typealias to Swift.InlineArray, hard to rename

### Option C: Use Different Names Entirely

Introduce new terminology like `.Embedded`, `.Local`, `.Stack`.

**Advantages**:
- Fresh start, no conflicts

**Disadvantages**:
- Non-standard terminology
- Loses connection to C++ `static_vector` and Rust `ArrayVec` precedent
- More cognitive load

### Evaluation

| Criterion | Option A (Array Convention) | Option B (Redefine) | Option C (New Names) |
|-----------|----------------------------|---------------------|----------------------|
| Follows established convention | ✓ Array sets precedent | ✗ Conflicts with Array | ~ Novel |
| Semantic precision | ✓ Inline ≠ Static | ✗ Loses distinction | ~ Depends |
| Breaking changes | 3 packages | 1 package | All packages |
| Industry alignment | ✓ static_vector | ~ | ✗ |

## Constraints

1. Array's convention is already shipped and documented
2. `Array.Inline` is a typealias to `Swift.InlineArray` (cannot easily rename)
3. All packages are pre-1.0; breaking changes acceptable
4. Consistency is required for clean layering

## Recommendation

**Option A: Standardize on Array Convention**

The Array package establishes clear semantics:
- **Inline** = Fixed count (always N), wraps `Swift.InlineArray`
- **Static** = Variable count (0 to N), compile-time capacity

### Migration Plan

| Step | Package | Change |
|------|---------|--------|
| 1 | storage-primitives | Rename `Storage.Inline` → `Storage.Static` |
| 2 | hash-table-primitives | Rename `Hash.Table.Inline` → `Hash.Table.Static` |
| 3 | set-primitives | Keep `Set.Ordered.Static` (already correct) |
| 4 | set-primitives | Update `Set.Ordered.Static` to use `Hash.Table.Static` |
| 5 | dictionary-primitives | Rename `Dictionary.Ordered.Inline` → `Dictionary.Ordered.Static` |
| 6 | dictionary-primitives | Update `Dictionary.Ordered.Static` to use `Set<Key>.Ordered.Static` |

### Target Layering

```
Dictionary.Ordered         → Set<Key>.Ordered         → Hash.Table<Key>
Dictionary.Ordered.Static  → Set<Key>.Ordered.Static  → Hash.Table<Key>.Static
Dictionary.Ordered.Small   → Set<Key>.Ordered.Small   → Hash.Table<Key>.Static (inline mode)
```

### Naming Convention Summary

| Name | Count | Capacity | Storage | Use Case |
|------|-------|----------|---------|----------|
| `.Inline<N>` | Fixed (N) | Compile-time | InlineArray directly | Fixed-size buffers, tuples |
| `.Static<N>` | Variable (0..N) | Compile-time | InlineArray + count | static_vector, ArrayVec |
| `.Small<N>` | Variable | Inline then heap | InlineArray + optional heap | SmallVec pattern |
| `.Fixed` | Variable | Runtime param | Heap | Throws on overflow |
| (base) | Variable | Dynamic | Heap | Growable containers |

## Outcome

**Status**: DECISION

Standardized on Array's convention: `.Static` for variable-count inline storage, `.Inline` for fixed-count wrappers.

**Implemented**: 2026-01-30

| Package | Commit |
|---------|--------|
| storage-primitives | `94ff48e` Rename Storage.Inline → Storage.Static |
| hash-table-primitives | `4d22577` Rename Hash.Table.Inline → Hash.Table.Static |
| dictionary-primitives | `7167fb9` Rename Dictionary.Ordered.Inline → Dictionary.Ordered.Static |

## References

- Array.swift lines 155-201: Static vs Inline distinction
- Swift stdlib InlineArray (SE-0453)
- C++ static_vector (P0843)
- Rust ArrayVec
