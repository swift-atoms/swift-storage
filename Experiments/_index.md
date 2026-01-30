# Storage Primitives Experiments

| Directory | Purpose | Date | Toolchain | Status |
|-----------|---------|------|-----------|--------|
| inline-span-access | Investigate approaches to enable Span access for Storage.Static | 2026-01-29 | Swift 6.2.3 | CONFIRMED |
| inline-span-copyable | Test InlineArray<capacity, Element> for Copyable elements | 2026-01-29 | Swift 6.2.3 | CONFIRMED |
| inline-uninitialized | Test approaches for uninitialized InlineArray with ~Copyable | 2026-01-29 | Swift 6.2.3 | REFUTED |

## Summary

These experiments investigate whether `Storage.Static` can support `Span`/`MutableSpan` access.

### Key Findings

1. **Fundamental constraint**: `InlineArray` requires `Copyable` for initialization (`init(repeating:)`). There is no `init(uninitializedCapacity:)` API.

2. **~Copyable + Span incompatibility**: For `~Copyable` elements, the only option is oversized slots (current 64-byte design), which breaks Span's dense layout expectation.

3. **Copyable enables Span**: For `Copyable` elements, `InlineArray<capacity, Element>` works and provides true dense packing compatible with Span.

### Recommended Solution

**Use the natural type split**:

| Need | Type | Layout | Access Pattern |
|------|------|--------|----------------|
| `~Copyable` elements | `Storage.Static` | 64-byte slots | `forEach`, `withElement` |
| Span access | `Storage` (heap) | Dense | `withSpan`, `withMutableSpan` |

**Rationale**: If you need Span access, you can afford heap allocation. If you need inline storage (stack allocation), you're in a performance-critical path where strided access is acceptable. Adding `Storage.Static.Dense` would add API complexity without enabling the primary use case (`~Copyable` with Span).

See: `Research/inline-storage-span-access.md` for full analysis.
