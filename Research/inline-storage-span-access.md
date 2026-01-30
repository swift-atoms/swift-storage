# Inline Storage Span Access

<!--
---
version: 1.0.0
last_updated: 2026-01-29
status: DECISION
---
-->

## Context

After fixing the pointer escape bug in `Storage.Static.read(at:)`, the question arose: can `Storage.Static` support `Span`/`MutableSpan` access?

**Trigger**: Investigation of whether strided element access (`forEach`, `withElement`) could be replaced with `Span` for `Storage.Static`.

## Question

Should `Storage.Static` provide `Span` access, and if not, what is the principled design?

## Analysis

### The Constraint

`Storage.Static` uses 64-byte slots (tuple-based `InlineArray`) because:

1. **`InlineArray.init(repeating:)` requires `Copyable`** — cannot create uninitialized storage for `~Copyable` elements
2. **No `InlineArray.init(uninitializedCapacity:)`** — this API doesn't exist in Swift 6.2
3. **Stride is runtime** — `MemoryLayout<Element>.stride` cannot be computed at compile time for generic `Element`

The 64-byte slot approach allows any element up to 64 bytes but creates a layout mismatch with `Span`, which expects dense packing at `MemoryLayout<Element>.stride` intervals.

### Experiments Conducted

Three experiments verified the constraints:

| Experiment | Result | Finding |
|------------|--------|---------|
| `inline-span-access` | CONFIRMED | Multiple approaches exist, none enable Span for `~Copyable` + truly inline |
| `inline-span-copyable` | CONFIRMED | `InlineArray<capacity, Element>` enables Span for `Copyable` elements |
| `inline-uninitialized` | REFUTED | No way to create uninitialized `InlineArray` for `~Copyable` in Swift 6.2 |

### Option A: Dual Storage Types

Add `Storage.Static.Dense<capacity>` for `Copyable` elements with Span support.

**Disadvantages**:
- Adds API complexity
- Users must choose between two types
- Overlaps with what `Storage` (heap) already provides

### Option B: Accept Natural Split (RECOMMENDED)

Use the existing types as designed:

| Need | Type | Layout | Access Pattern |
|------|------|--------|----------------|
| `~Copyable` elements | `Storage.Static` | 64-byte slots | `forEach`, `withElement` |
| Span access | `Storage` (heap) | Dense | `withSpan`, `withMutableSpan` |

**Insight**: If you need Span access, you can afford heap allocation. If you need inline storage (stack allocation), you're in a performance-critical path where the strided access is acceptable.

### Why This Is Principled

1. **No artificial complexity** — Each type does one thing well
2. **Clear selection criteria** — `~Copyable` or stack-only → Inline; need Span → heap Storage
3. **No dead code** — No `Storage.Static.Dense` that nobody uses
4. **Matches reality** — Swift 6.2 constraints make true generic inline Span impossible anyway

## Comparison

| Criterion | A: Dual Types | B: Natural Split |
|-----------|---------------|------------------|
| API simplicity | Worse | Better |
| Implementation | More code | No new code |
| User decision | "Which inline?" | "Inline or heap?" |
| Span for ~Copyable | Still no | N/A |
| Future-proof | Obsolete if SE adds uninitialized InlineArray | Still valid |

## Outcome

**Status**: DECISION

**Decision**: Do not add `Storage.Static.Dense`. The natural split is correct:

- `Storage.Static`: 64-byte slots, `~Copyable` support, strided access
- `Storage`: Heap, dense packing, Span support

**Rationale**: Creating a dense inline variant adds complexity without enabling the primary use case (`~Copyable` with Span). Users who need Span can use heap storage; the allocation cost is acceptable for that use case.

**Documentation**: Update `Storage.Static` documentation to clarify:
- Span is not supported due to 64-byte slot layout
- Use `forEach` and `withElement` for iteration
- For Span access, use heap-based `Storage` instead

## Future Consideration

If Swift Evolution adds `InlineArray.init(uninitializedCapacity:)` (enabling uninitialized inline storage for `~Copyable`), revisit this decision. Such an API would enable a single `Storage.Static` implementation with dense packing and Span support.

## References

- `Experiments/inline-span-access/` — approach investigation
- `Experiments/inline-span-copyable/` — Copyable-only Span verification
- `Experiments/inline-uninitialized/` — uninitialized storage investigation
- `Research/inline-storage-read-pointer-escape.md` — related pointer escape fix
