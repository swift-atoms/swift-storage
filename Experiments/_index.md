# Storage Primitives Experiments

| Directory | Purpose | Date | Toolchain | Status |
|-----------|---------|------|-----------|--------|
| inline-span-access | Investigate approaches to enable Span access for Storage.Static | 2026-01-29 | Swift 6.2.3 | CONFIRMED |
| inline-span-copyable | Test InlineArray<capacity, Element> for Copyable elements | 2026-01-29 | Swift 6.2.3 | CONFIRMED |
| inline-uninitialized | Test approaches for uninitialized InlineArray with ~Copyable | 2026-01-29 | Swift 6.2.3 | REFUTED |
| inline-storage-best-of-both-worlds | Parameterized Slot type for zero-overhead dense packing + ~Copyable | 2026-02-05 | Swift 6.2 | CONFIRMED |
| rawlayout-automatic-sizing | @_rawLayout(likeArrayOf:count:) for AUTOMATIC optimal layout | 2026-02-05 | Swift 6.2 | CONFIRMED |
| contiguous-protocol-conformance | Test Memory.Contiguous.Protocol conformance for Storage.Heap and Storage.Inline | 2026-02-05 | Swift 6.2 | CONFIRMED |
| span-copyable-constraint | Validate Span<Element> constraint behavior in ~Copyable extensions | 2026-02-05 | Swift 6.2 | CONFIRMED |
| bitvector-slot-tracking | Test Bit.Vector.Static for per-slot initialization tracking | 2026-02-05 | Swift 6.2.3 | CONFIRMED |
| nonmutating-copy-accessor | Non-mutating Property accessor for copy on ~Copyable types | 2026-02-06 | Swift 6.2 | CONFIRMED |
| nary-soa-feasibility | N-ary SoA feasibility: packs (PARTIAL), fixed-arity/HList/schema/handles (CONFIRMED) | 2026-02-07 | Swift 6.2.3 | PARTIAL |

### Removed (2026-03-21)

8 deinit-related experiments were consolidated into `swift-buffer-primitives/Experiments/` and deleted:
- `rawlayout-wrapper-validation/`, `rawlayout-deinit-crossmodule/`, `rawlayout-deinit-incremental/`, `rawlayout-deinit-investigation/`, `rawlayout-noncopyable-elements/` → `rawlayout-llvm-verifier-crash/`
- `discard-self-availability/`, `deinit-guard-idempotence/`, `escapable-deinit-lifetime/` → `rawlayout-deinit-alternatives/`

## Summary

These experiments investigate how `Storage.Inline` can achieve zero-overhead dense packing while supporting `~Copyable` elements.

### Key Findings

1. **`@_rawLayout` is the ideal solution**: `@_rawLayout(likeArrayOf: Element, count: capacity)` computes optimal layout automatically — no user-specified slot type needed.

2. **Automatic layout computation**: The compiler derives `size = stride(Element) × capacity` and `alignment = alignment(Element)` at compile time for ANY element type, including `~Copyable`.

3. **Parameterized slot as fallback**: If `@_rawLayout` is unacceptable (underscored API), `Storage.Inline<Element, capacity, Slot>` with backing types like `Int`, `UInt8`, or `InlineArray<N, Int>` achieves equivalent results.

4. **No wrapper type needed**: Using primitives directly as the slot type works identically to a `Cell<count, Base>` wrapper.

### Recommended Solution

**Option 1: `@_rawLayout` (ideal)**

```swift
@_rawLayout(likeArrayOf: Element, count: capacity)
struct Inline<Element: ~Copyable, let capacity: Int>: ~Copyable {}
```

- Automatic optimal layout
- No slot parameter
- Works with ALL element types and sizes
- Trade-off: underscored attribute (not ABI-stable)

**Option 2: Parameterized slot (stable)**

```swift
struct Inline<Element: ~Copyable, let capacity: Int, Slot: BitwiseCopyable & Sendable>: ~Copyable {
    var _storage: InlineArray<capacity, Slot>
}
```

- Consumer specifies slot type
- ADT layer provides sensible defaults
- Trade-off: additional generic parameter

### Comparison

| Element | Count | @_rawLayout | Slot param | 64B slots | Savings |
|---------|------:|------------:|-----------:|----------:|--------:|
| Double | 4 | 32 B | 32 B | 256 B | 87% |
| UInt8 | 16 | 16 B | 16 B | 1024 B | 98% |
| Int32 | 8 | 32 B | 32 B | 512 B | 93% |
| Resource(16B) | 4 | 64 B | 64 B | 256 B | 75% |
| FiveInts(40B) | 3 | 120 B | 120 B | 192 B | 37% |

Both approaches achieve identical optimal sizing. `@_rawLayout` eliminates the slot parameter entirely.

See: `Research/inline-slot-type-organization.md` for detailed analysis.
