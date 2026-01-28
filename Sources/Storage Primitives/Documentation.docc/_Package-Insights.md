# Storage Primitives Insights

<!--
---
title: Storage Primitives Insights
version: 1.0.0
last_updated: 2026-01-28
applies_to: [swift-storage-primitives]
normative: false
---
-->

@Metadata {
    @TitleHeading("Storage Primitives")
}

Design decisions, implementation patterns, and lessons learned specific to this package.

## Overview

This document captures insights that emerged during development of swift-storage-primitives. These are not API requirements—they are recorded decisions and patterns that inform future work on this package.

**Document type**: Non-normative (recorded decisions, not requirements).

**Consolidation source**: Reflection entries tagged with `[Package: swift-storage-primitives]`.

---

## Genuine Partiality vs Artificial Partiality

**Date**: 2026-01-27

**Context**: Deciding which operations should throw and which should be total after the @_disfavoredOverload fix.

After fixing `@_disfavoredOverload` placement, each `try!` needed evaluation: was it hiding genuine partiality or artificial partiality?

**Genuine partiality**: `Contiguous.predecessor` at index zero. There is no predecessor—the operation is mathematically undefined. Throwing is correct.

**Artificial partiality**: `Ring.successor` at any index. With modular arithmetic, every position has a successor. The `try!` existed only because `.one` resolved to `Offset.one` instead of `Count.one`.

Ring buffer arithmetic became total by restructuring:

```swift
// Successor: use Count.one (total) instead of Offset.one (throws)
(index + Index<Element>.Count.one) % capacity

// Predecessor: use saturating subtraction to compute (capacity - 1) as a Count
(index + capacity.subtract.saturating(Index<Element>.Count.one)) % capacity
```

The choice between `Count.one` and `Offset.one` encodes more than a value—it encodes whether the caller expects failure to be possible. Using `Count` for inherently non-negative operations documents the totality in the type.

**Applies to**: `Storage.Ring` successor/predecessor, `Storage.Contiguous` operations, totality analysis.

---

## Typed Errors for Init Preconditions

**Date**: 2026-01-27

**Context**: Converting Storage.Inline preconditions to typed throws.

The original `Storage.Inline.init()` used preconditions:

```swift
precondition(MemoryLayout<Element>.stride <= 64)
precondition(MemoryLayout<Element>.alignment <= MemoryLayout<Int>.alignment)
```

These trap at runtime if violated. But why is inline storage for a 128-byte struct a crash rather than a recoverable error? The constraint is clear (storage only supports elements ≤64 bytes), the violation is detectable, and recovery is possible (use heap storage instead).

The error type with associated values makes diagnostics trivial:

```swift
public enum Error: Swift.Error, Sendable {
    case strideExceedsSlotSize(stride: Int, maxSlotSize: Int)
    case alignmentExceedsStorageAlignment(alignment: Int, maxAlignment: Int)
}
```

Instead of "precondition failed," the caller sees "stride 128 exceeds max slot size 64." The error carries the information needed to understand and recover from the failure. The `throws(Error)` signature constrains the error type—callers know exactly what can fail.

**Applies to**: `Storage.Inline.init`, typed throws patterns, recoverable initialization errors.

---

## The Monus Operation for Total Ring Buffer Arithmetic

**Date**: 2026-01-27

**Context**: Making Ring.predecessor total without throwing.

Ring buffer predecessor seems to require subtraction: "one position before index, wrapping at capacity." But `index - 1` is partial (fails at index 0). How do we express "predecessor with wrap" as a total operation?

In a ring of size N, the predecessor of position P is position (P + N - 1) mod N. The key insight: (N - 1) is a Count-domain operation, not an Index-domain operation. We're computing "capacity minus one" before adding it to an index.

The monus operation (a ∸ b = max(0, a - b)) makes Count subtraction total:

```swift
capacity.subtract.saturating(Index<Element>.Count.one)
```

If capacity ≥ 1, this returns capacity - 1 as a Count. If capacity is 0 (edge case), this returns 0. Either way, it's a valid Count that can be added to an index.

The full predecessor:

```swift
(index + capacity.subtract.saturating(Index<Element>.Count.one)) % capacity
```

Every operation is total: Count subtraction via monus, Index + Count addition, Index % Count modulo. No throws, no preconditions, no force-unwraps.

Totality should be the default. When an operation seems partial, look for alternative formulations that achieve the same result through total operations.

**Applies to**: `Storage.Ring.predecessor`, monus (saturating subtraction), total arithmetic formulations.

---

## Topics

### Related Documents

- <doc:Storage-Ring>
- <doc:Storage-Contiguous>
- <doc:Storage-Inline>
