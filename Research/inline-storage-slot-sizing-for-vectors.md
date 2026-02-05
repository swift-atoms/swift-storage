# Inline Storage 64-Byte Slot Design Analysis

<!--
---
version: 2.0.0
last_updated: 2026-02-04
status: RECOMMENDATION
tier: 2
---
-->

## Context

The Swift Institute architecture requires ADT → Buffer → Storage layering. All inline ADT variants (Vector.Inline, Stack.Static, Queue.Static, etc.) should ultimately be backed by `Storage.Inline`. During the vector-primitives refactor, the 64-byte fixed slot design of `Storage.Inline` was questioned: a `Vector<Double, 4>.Inline` would go from 32 bytes (raw `InlineArray`) to 256+ bytes (4 × 64-byte slots + initialization header). This investigation asks whether `Storage.Inline` is correct in its current design.

**Trigger**: Vector-primitives refactor revealed that `Storage.Inline`'s 64-byte slots create unacceptable size overhead for small-element containers.

## Question

Is `Storage.Inline`'s 64-byte fixed slot design correct as a universal inline storage primitive, or does it need to change?

## Analysis

### 1. Why 64-Byte Slots Exist

The backing store is (`Storage.Inline.swift:48`):

```swift
InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>
```

This is `8 × 8 = 64 bytes` per slot on 64-bit platforms. The design exists because of three Swift 6.2 constraints:

| Constraint | Explanation |
|-----------|-------------|
| `InlineArray.init(repeating:)` requires `Copyable` | Cannot create `InlineArray<N, Element>` when `Element: ~Copyable` |
| No `InlineArray.init(uninitializedCapacity:)` | Swift 6.2 provides no way to allocate uninitialized inline storage |
| `MemoryLayout<Element>.stride` is runtime | Cannot parameterize the backing tuple on element stride at compile time |

The workaround: use a **Copyable tuple** as the backing type, large enough for "most" elements, then raw-pointer elements into the slots. This is the only mechanism available in Swift 6.2 for inline storage of `~Copyable` elements.

**Conclusion: Some form of oversized Copyable-backed slot IS necessary for `~Copyable` support.** This is a language constraint, not a design error.

### 2. Is 64 Bytes the Right Slot Size?

The choice of 64 bytes is not principled — it's a pragmatic guess. Let's analyze:

| Slot Size | Covers | Overhead for `Double` (8B) | Overhead for `Int` (8B) | Overhead for `UInt8` (1B) | Overhead for `SIMD4<Float>` (16B) |
|-----------|--------|---------------------------|------------------------|--------------------------|----------------------------------|
| 8 bytes | `Int`, `Double`, pointers | 1× | 1× | 8× | Cannot fit |
| 16 bytes | + `SIMD2`, `(Int, Int)` | 2× | 2× | 16× | 1× |
| 32 bytes | + `SIMD4`, small structs | 4× | 4× | 32× | 2× |
| **64 bytes** (current) | + medium structs, closures | **8×** | **8×** | **64×** | **4×** |
| 128 bytes | + large structs | 16× | 16× | 128× | 8× |

Size impact on concrete Vector types:

| Vector Type | Dense (`InlineArray`) | 64-byte slots | 16-byte slots | 8-byte slots |
|-------------|----------------------|---------------|---------------|--------------|
| `Vector<Double, 4>.Inline` | 32 B | 256 B + header | 64 B + header | 32 B + header |
| `Vector<Int, 8>.Inline` | 64 B | 512 B + header | 128 B + header | 64 B + header |
| `Vector<UInt8, 16>.Inline` | 16 B | 1024 B + header | 256 B + header | 128 B + header |
| `Vector<SIMD4<Float>, 4>.Inline` | 64 B | 256 B + header | 64 B + header | Cannot fit |

The `Initialization` header (`Storage.Initialization.swift:38`) adds further overhead: it's an enum with associated `Range<Index<Storage>>` values.

### 3. Fundamental Tension: Universality vs. Efficiency

`Storage.Inline` tries to be universal — one type for all inline storage needs. But the 64-byte slot creates a forced tradeoff:

- **Too large for small elements**: 8×–64× waste for the common case (`Int`, `Double`, `UInt8`)
- **Too small for large elements**: Already throws `strideExceedsSlotSize` for elements > 64 bytes (`Storage.Inline.swift:59-63`)
- **Cannot support Span**: 64-byte striding prevents dense `Span` access (`inline-storage-span-access.md`, DECISION)

The current design optimizes for **generality over efficiency** — it accepts any element ≤ 64 bytes at the cost of wasted space.

### 4. Could Storage.Inline Use Conditional Backing?

The ideal would be: use `InlineArray<N, Element>` when `Element: Copyable` (dense, Span-compatible), fall back to 64-byte slots only when `Element: ~Copyable`. But Swift doesn't support conditional stored properties:

```swift
// NOT VALID SWIFT:
struct Inline<Element: ~Copyable, let capacity: Int>: ~Copyable {
    var _storage: InlineArray<capacity, Element> where Element: Copyable  // ❌
    var _storage: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)> where Element: ~Copyable  // ❌
}
```

You would need two separate types. This is essentially what `inline-storage-span-access.md` rejected as "Dual Storage Types" — but that analysis was about adding a second type alongside Storage.Inline, not about whether Storage.Inline itself is correct.

### 5. Options

#### Option A: Storage.Inline Is Correct As-Is

Accept 64-byte slots as the cost of `~Copyable` universality. Consumers that care about size can use heap storage instead.

**Assessment**: This conflicts with the ADT → Buffer → Storage architecture. If Vector.Inline must use Storage.Inline, the 8×–64× bloat is structural, not optional. "Use heap instead" undermines the purpose of having an inline variant.

#### Option B: Reduce Slot Size

Use a smaller tuple, e.g., `(Int, Int)` = 16 bytes. This covers `Int`, `Double`, `SIMD2`, pointers, and most primitive types. Elements > 16 bytes would need heap storage.

**Assessment**: Reduces waste from 8× to 2× for common types. But 16 bytes is still 16× overhead for `UInt8`, and excludes `SIMD4<Float>` (16 bytes stride — barely fits). The 64-byte limit was chosen to accommodate "most" types; shrinking it narrows the applicability. It's a different tradeoff point on the same spectrum, not a fundamentally different design.

#### Option C: Parameterize Slot Size

Add a slot size parameter:

```swift
Storage.Inline<Element: ~Copyable, let capacity: Int, let slotBytes: Int>
```

backed by `InlineArray<capacity, /* tuple of slotBytes/8 Ints */>`. This lets consumers choose: `Storage.Inline<Int, 8, 8>` for tight packing, `Storage.Inline<LargeStruct, 4, 64>` for large elements.

**Assessment**: Swift 6.2 integer generic parameters (`let N: Int`) could in principle support this, but you can't dynamically construct a tuple type from an integer. The backing `InlineArray` element type must be a concrete type. You'd need a family of fixed sizes (8, 16, 32, 64, 128) with different backing tuples — essentially multiple types behind a facade.

#### Option D: Defer Inline Variant Until Swift Fixes the Constraint

The root cause is Swift 6.2's lack of `InlineArray.init(uninitializedCapacity:)`. If/when Swift Evolution adds this, `Storage.Inline` could use `InlineArray<N, Element>` directly for all elements, including `~Copyable`. Dense packing, Span support, no waste.

**Assessment**: This is the cleanest solution but depends on an external timeline. It means the inline variant of every ADT is blocked on a Swift Evolution proposal. However, this is exactly what `inline-storage-span-access.md` identified as the future resolution.

#### Option E: Tiered Slot Sizes (Family of Types)

Provide Storage.Inline at multiple slot sizes, keyed to common element stride ranges:

```swift
Storage.Inline8<Element: ~Copyable, let capacity: Int>   // (Int) = 8 bytes
Storage.Inline16<Element: ~Copyable, let capacity: Int>  // (Int, Int) = 16 bytes
Storage.Inline64<Element: ~Copyable, let capacity: Int>  // (Int×8) = 64 bytes (current)
```

Or use a single type with a marker protocol for slot tier selection.

**Assessment**: Adds API surface and forces consumers to choose a tier. The choice depends on `MemoryLayout<Element>.stride`, which is runtime — so the consumer would need to know their element's stride at design time, not just at runtime. For generic code (`Storage.Inline<T, N>` where T is unconstrained), you'd still need the largest slot size.

### 6. The Core Issue

The 64-byte slot is not wrong — it's a **necessary consequence** of Swift 6.2's constraints for `~Copyable` inline storage. The question is whether the waste it introduces is acceptable for the ADT → Buffer → Storage architecture.

For ADTs like `Stack.Static<LargeStruct, 4>`, it's fine — the elements are large, the waste is proportionally small, and the alternative (heap) has its own overhead.

For containers like `Vector<Double, 4>.Inline`, it's problematic — the waste dominates. But this is inherent to the `~Copyable` workaround, not to a design flaw in Storage.Inline.

**The slot-based approach is the only viable mechanism for `~Copyable` inline storage in Swift 6.2.** The question is whether 64 bytes is the right fixed point, or whether multiple slot sizes should be offered.

## Comparison

| Criterion | A: Keep 64B | B: Reduce to 16B | C: Parameterize | D: Defer | E: Tiered Family |
|-----------|------------|-------------------|-----------------|----------|------------------|
| Correctness | ✓ | ✓ (narrower) | ✓ | N/A | ✓ |
| Small-element waste | 8×–64× | 2×–16× | 1×–configurable | 1× (future) | Configurable |
| Large-element support | ≤ 64B | ≤ 16B | Configurable | Universal | Configurable |
| API complexity | Simple | Simple | Complex | Simple (future) | Moderate |
| Span support | No | No | No | Yes (future) | No |
| Swift 6.2 feasible | ✓ | ✓ | Partially | ✗ | ✓ |
| Generic code usability | ✓ | ✓ | Difficult | ✓ | Difficult |

## Constraints

1. `InlineArray.init(repeating:)` requires `Copyable` — fundamental, cannot work around
2. No `InlineArray.init(uninitializedCapacity:)` — the root cause; would eliminate the need for fixed slots entirely
3. ADT → Buffer → Storage layering requires Vector.Inline to use Storage.Inline
4. Tuple type cannot be parameterized by a runtime integer — slot size must be a compile-time type choice
5. Swift doesn't support conditional stored properties based on generic constraints

## Recommendation

**Status**: RECOMMENDATION

**Storage.Inline's 64-byte slot mechanism is correct in principle — it's the only viable approach for `~Copyable` inline storage in Swift 6.2.** The specific 64-byte size is a pragmatic choice, not a principled one.

**Recommended path forward**:

1. **Accept Storage.Inline as correct for now.** The 64-byte slot is a language constraint workaround, not a design flaw. Document it as such.

2. **For Vector.Inline specifically**: the size overhead (8× for `Double`, 64× for `UInt8`) is significant enough that it should be acknowledged as a known cost. Vectors are the worst case because they're typically used with small primitive types at small dimensions — exactly where the waste is most visible.

3. **Track the Swift Evolution dependency.** The real fix is `InlineArray.init(uninitializedCapacity:initializingWith:)` for `~Copyable` elements. When that lands, `Storage.Inline` can switch to `InlineArray<N, Element>` directly, eliminating the slot mechanism, enabling Span, and achieving dense packing. All consumers benefit automatically.

4. **Do not add tiered slot sizes or dual types.** The complexity is not justified for a workaround that will be obsoleted by a language feature. Better to accept the overhead now than to build throwaway abstractions.

**Open question for the co-architect**: Is the 8× overhead for `Vector<Double, 4>.Inline` (256 bytes vs 32 bytes) acceptable in practice, given that:
- Inline vectors are typically short-lived stack values
- The overhead is bounded (capacity × 56 wasted bytes for Double)
- The alternative is blocking the inline variant entirely until Swift adds uninitialized InlineArray

Or does this warrant deferring Vector.Inline until the language constraint is resolved?

## Prior Art

- `inline-storage-span-access.md` (DECISION) — rejected dual inline storage types; identified `InlineArray.init(uninitializedCapacity:)` as future resolution
- `inline-variant-naming-consistency.md` (CONTEXTUALLY SUPERSEDED) — Inline vs Static naming at storage vs ADT layers
- `storage-ownership-reference-synthesis.md` (IN_PROGRESS) — storage names encode placement only; count semantics layered above
- Swift Evolution SE-0453: `InlineArray` — no uninitialized initializer for `~Copyable`

## References

- `Storage.Inline.swift:46-48` — 64-byte tuple slot definition
- `Storage.Inline.swift:58-63` — stride validation guard
- `Affine.Discrete.Ratio+Storage.swift:19-23` — hardcoded 64-byte stride ratio
- `Storage.Initialization.swift:38-51` — initialization tracking enum
- `Storage.Inline.Error.swift:14-15` — stride/alignment error cases
- `inline-storage-span-access.md` — prior decision on Span incompatibility
