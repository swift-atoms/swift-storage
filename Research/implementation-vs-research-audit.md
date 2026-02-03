# Storage Primitives: Implementation vs Research Audit

<!--
---
version: 1.0.0
last_updated: 2026-02-03
status: ANALYSIS
tier: 2
applies_to: [swift-storage-primitives]
---
-->

## Purpose

Compare the current `swift-storage-primitives` implementation against the centralized research corpus to identify:
1. Implemented but not researched
2. Researched but not implemented
3. Implementation diverges from research decisions
4. Open questions blocking implementation

---

## 1. Implementation Inventory

### Current Types (as of 2026-02-03)

| Type | File | Role |
|------|------|------|
| `Storage` (enum) | Storage.swift | Namespace |
| `Storage.Dynamic<Element>` | Storage.swift:51 | Heap storage via ManagedBuffer |
| `Storage.Static<Element, let capacity>` | Storage.swift:108 | Inline fixed-capacity, 64-byte slots |
| `Storage.Heap.Header` | Storage.Heap.Header.swift | ManagedBuffer header (wraps Initialization) |
| `Storage.Initialization` | Storage.Initialization.swift | empty / one(Span) / two(first, second) |
| `Storage.Span` | Storage.Span.swift | Half-open slot interval [start, end) |
| `Storage.Slot` | Storage.Slot.swift | `Tagged<Storage, Ordinal>` physical coordinate |
| `Storage.Shift` | Storage.Shift.swift | Tag for `.shift.left(removedAt:count:)` property |

### Current Modules

| Module | Contents |
|--------|----------|
| Storage Primitives Core | Storage, Dynamic, Static, Header, Initialization, Span, Slot, Shift |
| Storage Dynamic Primitives | Extensions on Storage.Dynamic (~Copyable + Copyable) |
| Storage Static Primitives | Extensions on Storage.Static (~Copyable + Copyable) |
| Storage Primitives | Re-exports all three |

---

## 2. Alignment with Research

### 2.1 Correctly Aligned

| Implementation | Research Source | Assessment |
|---------------|---------------|------------|
| `Storage.Slot = Tagged<Storage, Ordinal>` | integration-maximization: phantom typing | Correct: zero-cost typed coordinate |
| `Storage.Initialization` with `.two(first:second:)` | Collection Primitives Architecture: ring buffer wrap | Correct: handles circular initialization |
| Conditional `Copyable`/`Sendable` on Static | Collection Primitives Architecture §5.1 | Correct: matches ADT patterns |
| Typed throws on `Static.init()` | first-principles §7 (current state analysis) | Correct: `throws(Error)` not bare `throws` |
| 64-byte slot design for Static | inline-storage-span-access | Correct: supports ~Copyable via InlineArray |
| No dense Span on Static | inline-storage-span-access (DECISION) | Correct: Span incompatible with 64-byte slots |
| `Storage.Heap.Header` wraps `Initialization` only | unified-storage-primitive: Header is metadata | Correct: simple, composable |
| Closure-based element access on Static | inline-storage-read-pointer-escape (DECISION) | Correct: prevents pointer escape |

### 2.2 Naming Conflict

**Issue**: Two research documents give contradictory rename guidance.

| Document | Says | Names |
|----------|------|-------|
| inline-variant-naming-consistency (DECISION) | "Inline = all-N-initialized (fixed count), Static = variable count (0 to N)" | Current names are CORRECT |
| storage-primitives-first-principles (IN_PROGRESS) | "Rename Static → Inline, Dynamic → Heap based on placement semantics" | Current names should CHANGE |

**Current implementation**:
- `Storage.Dynamic` — heap-allocated, variable count → first-principles says rename to `Heap`
- `Storage.Static` — inline, variable count (0 to N with initialization tracking) → naming-consistency says `Static` is correct for variable-count

**The conflict**: The naming-consistency decision uses a *count-semantics* axis (all-initialized vs variable-initialized). The first-principles research uses a *placement* axis (inline vs heap). These are different axes.

**Doc comment inconsistency**: The namespace doc comment at Storage.swift:22 already says `Storage/Heap`, but the class is named `Dynamic`. The old name and the doc comment disagree.

**Resolution needed**: This must be decided before proceeding. The two axes are:

| Axis | Dynamic → | Static → |
|------|-----------|----------|
| Placement | Heap | Inline |
| Count semantics | (no change needed) | Static (variable) vs Inline (fixed) |

If placement wins: `Storage.Heap`, `Storage.Inline`
If count-semantics wins: `Storage.Dynamic`, `Storage.Static` (current names stay)
If both: `Storage.Heap`, `Storage.Static` (hybrid — heap by placement, static by count)

### 2.3 Researched but Not Implemented

| Research Decision | Status | Blocking? |
|------------------|--------|-----------|
| `Index % Count → Index` projection operator | ring-buffer-index-arithmetic (DECISION) | Not blocking storage — belongs in index-primitives |
| `Index.Bounded<N>` cyclic group arithmetic | ring-buffer-index-arithmetic (DECISION) | Not blocking storage — belongs in index-primitives |
| `Storage.Ring` (index operations) | storage-primitives-design (SUPERSEDED) | Not needed — access discipline belongs at ADT layer per first-principles |
| `Storage.Heap.Header.Count`, `.Ring`, `.Arena` | storage-primitives-design (SUPERSEDED) | Not needed — ADTs manage their own headers. Current simple Header is sufficient. |
| `PTR-INT-001`: Pointer.advanced(by: Index\<T\>.Offset) | integration-maximization (RECOMMENDATION) | Not blocking storage — belongs in pointer-primitives |
| `PTR-INT-002`: Pointer.distance(to:) → Index\<T\>.Offset | integration-maximization (RECOMMENDATION) | Not blocking storage — belongs in pointer-primitives |
| `Memory.Pool` | first-principles, synthesis | Future phase — when Slab/Buffer.Slots needs it |
| `Storage.External` | first-principles, synthesis | Future phase — no consumer yet |

### 2.4 Implemented but Not Researched

| Implementation | Assessment |
|---------------|------------|
| `Storage.Shift` tag type | Implementation detail for shift-left operations. No research covers it, but it follows the Property pattern from property-primitives. Acceptable. |
| `Affine.Discrete.Ratio<Storage, Memory>.stride` (64-byte constant) | Used for slot sizing. Mentioned in inline-storage-span-access but not independently researched. The choice of 64 bytes is pragmatic, not derived from theory. Worth documenting rationale. |
| Dual Index-based AND Slot-based APIs on Dynamic | Storage.Dynamic has both `pointer(at: Index<Element>)` and `pointer(at: Storage.Slot)`. The Index-based API appears to be backward compatibility. Research doesn't address when to prefer which. |

### 2.5 Implementation Diverges from Research

| Divergence | Research Says | Implementation Does | Severity |
|-----------|--------------|---------------------|----------|
| Doc comment vs class name | first-principles: rename to Heap | Code: `Dynamic`, doc comment: `Storage/Heap` | Medium — inconsistent but functional |
| Specialized headers | original design: Header.Count, Header.Ring, Header.Arena | Single Header with Initialization only | Low — current design is simpler and validated by unified-storage-primitive |
| Storage.Ring operations | original design: static methods for ring arithmetic | Not present in storage-primitives | Low — correctly moved to index-primitives per first-principles |
| Layered approach | unified-storage-primitive: three categories (contiguous, ring, hash) | Single Dynamic + Static | Low — categories moved to ADT layer as recommended |

---

## 3. Summary of Findings

### What's Right

The current implementation is architecturally sound. The core abstractions — `Storage.Slot` as a phantom-typed coordinate, `Storage.Initialization` with ring buffer support, `Storage.Span` for contiguous slot ranges, and the `Dynamic`/`Static` split — are well-designed and align with the settled research decisions.

### What Needs Decision

**One blocking decision**: The naming conflict between placement-axis (`Heap`/`Inline`) and count-axis (`Dynamic`/`Static`). The doc comments already lean toward `Heap`. The naming consistency DECISION favors keeping `Static`. These need reconciliation.

### What Can Proceed Independently

| Action | Package | Dependency |
|--------|---------|------------|
| `Index % Count → Index` | index-primitives | None |
| `Index.Bounded<N>` ℤ/Nℤ | index-primitives | None |
| `PTR-INT-001/002` | pointer-primitives | None |
| `Memory.Pool` | memory-primitives | When Slab needs it |
| Document 64-byte slot rationale | storage-primitives | None |
| Clean up dual Index/Slot API | storage-primitives | Naming decision |

---

## 4. Recommendation

1. **Resolve the naming conflict first** — this is the only blocking item for the storage rebuild.
2. **The rest of storage-primitives is implementation-ready** — the research corpus provides clear guidance for everything else.
3. **Pointer and index improvements should proceed in parallel** — they don't block storage but improve the overall stack.
