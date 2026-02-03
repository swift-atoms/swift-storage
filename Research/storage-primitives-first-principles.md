# Storage Primitives: First-Principles Redesign

<!--
---
version: 1.0.0
last_updated: 2026-02-01
status: IN_PROGRESS
tier: 3
applies_to: [swift-storage-primitives]
---
-->

## Context

Storage-primitives currently exists at Tier 12 with a specific implementation focused on `ManagedBuffer`-based heap storage and inline static storage. This research proposes a ground-up redesign based on first principles from academic literature.

**Trigger**: Request to rebuild storage-primitives from the ground up with the latest academic research.

**Scope**: Ecosystem-wide (establishes long-lived semantic contract).

**Prior Work**:
- `storage-primitives-design.md` (v1.0.0, 2026-01-26) - Original design
- `unified-storage-primitive.md` (v1.0.0, 2026-01-29) - Layered approach recommendation
- ChatGPT preliminary analysis on storage as placement, ownership, and lifetime

---

## Research Questions

Per [RES-023] Systematic Literature Review methodology:

| ID | Question |
|----|----------|
| RQ1 | What are the canonical academic definitions of "storage" in programming language theory? |
| RQ2 | How do major PL research traditions decompose storage? |
| RQ3 | What formal semantics exist for storage lifetime, ownership, and placement? |
| RQ4 | What is the academic distinction between storage vs. buffer vs. container/ADT? |

---

## Part I: Systematic Literature Review

### 1. Foundational Definitions of Storage

#### 1.1 The Scott-Strachey Denotational View

The foundational definition comes from Christopher Strachey and Dana Scott's denotational semantics (early 1970s):

> **Storage (Store)** is a finite partial function from *locations* to *values*.

- A **location** is an abstract address that can hold a value
- **Assignment** is a function that takes a state (store) to a new state with a location updated
- The meaning of `x := 3` is the function that takes a state to the state with 3 assigned to x

**Source**: Scott & Strachey, "Toward a Mathematical Semantics for Computer Languages" (1971)

#### 1.2 Girard's Linear Logic View

In Girard's linear logic (1987), storage is reconceptualized through the modal operator `!` ("of course"):

- Resources without `!` must be used **exactly once** (linear)
- The `!` operator creates "storage" that permits unlimited duplication and discarding
- `!A` represents "a printing press for A's, which can generate any number of A's"

**Source**: Girard, "Linear Logic" - Theoretical Computer Science 50 (1987)

#### 1.3 Typed Operational Semantics View

In Wright and Felleisen's typed operational semantics (1994):

- **Store typing**: A typing environment mapping locations to their types
- **Store conformance**: A store conforms iff every location's value conforms to its declared type
- **Type preservation**: Well-typedness remains invariant as computation progresses

**Source**: Wright & Felleisen, "A Syntactic Approach to Type Soundness" (1994)

---

### 2. Major PL Traditions on Storage

#### 2.1 Linear Types and Substructural Type Systems

Walker's taxonomy (2005) based on structural rules:

| Type System | Exchange | Weakening | Contraction | Usage |
|-------------|----------|-----------|-------------|-------|
| **Linear** | Yes | No | No | Exactly once |
| **Affine** | Yes | Yes | No | At most once |
| **Relevant** | Yes | No | Yes | At least once |
| **Ordered** | No | No | No | Exactly once, in order |

Wadler's key insight (1990):
- Linear values require **no garbage collection or reference counting**
- Linear types safely admit **destructive array update**

**Sources**:
- Walker, "Substructural Type Systems" in ATTAPL (2005)
- Wadler, "Linear Types Can Change the World!" (1990)

#### 2.2 Region-Based Memory Management

Tofte & Talpin (1997) established the foundation:

> A **region** is a contiguous segment of memory deallocated all at once.

Core properties:
- No garbage collector required
- Region inference is decidable
- Allocation is O(1) (bump pointer within region)
- Deallocation is O(1) (entire region freed at once)

Cyclone (Grossman et al., 2002-2006) extended this:
- Every pointer type includes a **region annotation**
- Functions are **region-polymorphic**

**Sources**:
- Tofte & Talpin, "Region-Based Memory Management" (1997)
- Grossman et al., "Region-Based Memory Management in Cyclone" (2002)

#### 2.3 Ownership Types

Clarke, Potter & Noble (1998) introduced ownership for alias protection:

- Objects have **owners** (other objects or special contexts like `world`)
- The `rep` keyword denotes that a reference cannot escape its containing object
- **Ownership forms a tree** (no cycles)

Boyapati et al. (2002-2003) combined ownership with regions:
- Ownership types provide **safe region-based memory management**
- Static guarantees eliminate need for runtime checks

**Sources**:
- Clarke et al., "Ownership Types for Flexible Alias Protection" (1998)
- Boyapati et al., "Ownership Types for Safe Region-Based Memory Management" (2003)

#### 2.4 Separation Logic

Reynolds (2002) developed separation logic:

- **Separating conjunction** (`*`): P * Q means P and Q hold for disjoint portions of memory
- **Frame rule**: Local reasoning about program components without global state
- Handles pointer aliasing explicitly

Fractional permissions (Boyland 2003):
- Permission `1` = write access
- Permissions in (0, 1) = read-only access
- Multiple read permissions can be combined back into write permission

**Sources**:
- Reynolds, "Separation Logic: A Logic for Shared Mutable Data Structures" (2002)
- Boyland, "Checking Interference with Fractional Permissions" (2003)

#### 2.5 Modern Synthesis: RustBelt and Oxide

RustBelt (Jung et al., 2018) provides formal verification of Rust's safety:
- Uses **Iris separation logic** for semantic soundness
- Introduces **lifetime logic** with borrow propositions
- Types have both **ownership predicates** and **sharing predicates**

Oxide (Weiss et al., 2019-2021) provides source-level formalization:
- First **syntactic type safety proof** for borrow checking
- Lifetimes as **approximation of reference provenances**

**Sources**:
- Jung et al., "RustBelt: Securing the Foundations of the Rust Programming Language" (2018)
- Weiss et al., "Oxide: The Essence of Rust" (2019-2021)

---

### 3. Synthesized Taxonomy: The Five Dimensions

Based on the literature review, storage is a multi-dimensional space:

#### Dimension 1: Structural Properties (Linear Logic)

| Property | Meaning | Swift Analog |
|----------|---------|--------------|
| **Unrestricted** | Arbitrary use | `Copyable` |
| **Affine** | At most once | `~Copyable` |
| **Linear** | Exactly once | `~Copyable` + deinit requirement |
| **Ordered** | Exactly once, in order | Not expressible |

#### Dimension 2: Spatial Organization (Region Theory)

| Organization | Deallocation | Swift Analog |
|--------------|--------------|--------------|
| **Inline** | With container | Value in struct/stack |
| **Stack** | Scope exit | Local `var` |
| **Heap** | ARC/manual | `class`, `ManagedBuffer` |
| **Arena** | Bulk free | `Memory.Arena` |
| **Pool** | Recycled slots | `Storage.Heap.Header.Arena` |

#### Dimension 3: Access Rights (Separation Logic)

| Permission | Read | Write | Share | Swift Analog |
|------------|------|-------|-------|--------------|
| **Unique/Owned** | Yes | Yes | No | `consuming` |
| **Exclusive Mutable** | Yes | Yes | No | `inout` |
| **Shared Immutable** | Yes | No | Yes | `borrowing` (immutable) |
| **Borrowed Mutable** | Yes | Yes | No | `borrowing` (mutable) |

#### Dimension 4: Lifetime Semantics (Ownership Theory)

| Lifetime | Determination | Swift Analog |
|----------|---------------|--------------|
| **Static** | Compile-time constant | Global `let` |
| **Lexical** | Syntactic scope | Local scope |
| **Non-Lexical** | Control-flow graph | Future Swift? |
| **Dynamic** | Runtime (ARC) | Reference types |

#### Dimension 5: Value Discipline (Move/Copy Theory)

| Semantics | On Assignment | Swift Analog |
|-----------|---------------|--------------|
| **Copy** | Duplicate | `Copyable` |
| **Move** | Transfer ownership | `~Copyable` consumption |
| **Borrow** | Temporary loan | `borrowing` parameter |

---

### 4. The Fundamental Distinction: Storage vs Buffer vs ADT

ChatGPT's preliminary analysis was correct. Academia converges on a clean separation:

#### Storage: Answers "How does memory exist?"

**Definition**: The underlying memory substrate characterized by:
- **Placement**: Where does state live? (address space, locality)
- **Ownership**: Who owns it? (aliasing, exclusivity)
- **Lifetime**: How long does it live? (reclamation discipline)

Storage is about the *existence* of addressable state, not its *use*.

#### Buffer: Answers "How is data transferred?"

**Definition**: A temporary holding area for data during transfer.

**Key Properties**:
- **Temporal**: Holds data transiently
- **Rate-matching**: Compensates for speed differences
- **Access pattern**: Defines how data enters/exits (linear, ring, etc.)

Buffers *use* storage but add access discipline.

#### Container/ADT: Answers "What operations are available?"

**Definition**: A data structure defined by behavior (semantics), not representation.

**Formal Definition**: ADT = (Domain, Operations, Constraints)
- Domain: Set of possible values
- Operations: Functions over the domain
- Constraints: Invariants the operations must satisfy

Containers *use* buffers and storage but define *meaning*.

#### Lattice Relationship

```
Container/ADT   →  semantics (what operations exist?)
     ↓
   Buffer       →  access discipline (how is data accessed?)
     ↓
   Storage      →  existence (how does memory exist?)
```

**Example**:
```
Queue                    ← ADT: enqueue/dequeue semantics
 └─ uses Buffer.Ring     ← Access: FIFO via wraparound
     └─ backed by Storage.Heap  ← Existence: heap-allocated, ARC-managed
```

---

## Part II: Proposed Storage Taxonomy

### 5. Academically Defensible Storage Primitives

Based on the synthesis, these are the irreducible storage forms:

#### 5.1 Storage.Inline

**Definition**: Storage embedded directly inside another value.

**Academic Roots**:
- Activation records (stack frames)
- Record layout (struct fields)
- Value semantics

**Properties**:
- No allocation
- Lifetime tied to enclosing value
- Zero indirection

**Swift Equivalent**: Stack locals, struct fields, `InlineArray`

#### 5.2 Storage.Stack

**Definition**: Storage with strictly lexical lifetime and LIFO discipline.

**Academic Roots**:
- Stack machines
- Lambda calculus environments
- Activation frames

**Properties**:
- Deterministic lifetime
- Zero fragmentation
- No escape allowed (enforced by type system)

**Note**: Inline is often stack-resident, but Stack is about *lifetime discipline*, not *placement*.

#### 5.3 Storage.Heap

**Definition**: Individually allocated storage with independent lifetime.

**Academic Roots**:
- Heap semantics
- Pointer machines
- GC theory

**Properties**:
- Arbitrary lifetime
- Fragmentation risk
- Requires ownership discipline (ARC, GC, manual)

**Swift Equivalent**: `class`, `ManagedBuffer`

#### 5.4 Storage.Arena (Region)

**Definition**: Bulk-allocated storage freed all at once.

**Academic Roots**:
- Tofte & Talpin's region inference (1997)
- Linear logic
- Compiler memory inference

**Properties**:
- O(1) allocation (bump pointer)
- O(1) deallocation (bulk free)
- Lifetime ≠ lexical nesting necessarily

**Swift Equivalent**: `Memory.Arena`

**Distinction from Heap**: Arena deallocation is bulk, not individual.

#### 5.5 Storage.Pool

**Definition**: Storage drawn from a fixed set of reusable slots.

**Academic Roots**:
- Slab allocators (Bonwick 1994)
- Object pools
- Free lists

**Properties**:
- Bounded capacity
- Predictable allocation cost
- Fragmentation-resistant
- Individual slot reuse

**Distinction from Arena**: Pool reuses individual slots; Arena frees everything together.

#### 5.6 Storage.View

**Definition**: Non-owning reference to existing storage.

**Academic Roots**:
- Borrowing (ownership types)
- Fat pointers
- Slices

**Properties**:
- No allocation
- No ownership transfer
- Lifetime constrained by source

**Swift Equivalent**: `Span`, `borrowing` parameters

#### 5.7 Storage.External

**Definition**: Storage not owned by the language runtime.

**Academic Roots**:
- Foreign memory
- MMIO
- Persistent memory

**Examples**:
- Memory-mapped files
- GPU buffers
- Disk-backed pages

**Properties**:
- Lifetime managed externally
- May require special access protocols
- Synchronization constraints from external system

---

### 6. What Is NOT a Storage Primitive

These concepts USE storage but do not DEFINE it:

| Concept | Why Not Storage |
|---------|-----------------|
| Buffer.Linear | Access discipline, not existence |
| Buffer.Ring | Indexing + wraparound pattern |
| Array | ADT (sequence semantics) |
| Set | ADT (membership semantics) |
| Queue | ADT (FIFO semantics) |
| BitSet | ADT (bit membership) |
| Vector | Sequence with growth semantics |

---

## Part III: Application to Swift Primitives

### 7. Current State Analysis

#### Current storage-primitives (Tier 12)

| Component | Purpose |
|-----------|---------|
| `Storage<Element>` | Heap storage via ManagedBuffer |
| `Storage.Static<N>` | Inline fixed-capacity storage |
| `Storage.Heap.Header.Count` | Count-only header |
| `Storage.Heap.Header.Arena` | Free-list arena header |
| `Storage.Contiguous` | Alias for heap storage |
| `Storage.Ring` | Ring buffer index operations |

**Observations**:
1. `Storage.Ring` is actually *access discipline*, not storage
2. `Storage.Heap.Header.*` are *metadata*, not storage itself
3. Missing: Pool, View, External, Stack (as distinct from Inline)

#### Current memory-primitives (Tier 10)

| Component | Purpose |
|-----------|---------|
| `Memory.Address` | Byte address as `Tagged<Memory, Ordinal>` |
| `Memory.Arena` | Bump allocator with bulk reset |
| `Memory.Buffer` | Non-null raw buffer view |
| `Memory.Allocator` | Allocation protocol |

**Observations**:
1. `Memory.Arena` IS a storage primitive
2. `Memory.Buffer` IS a view primitive
3. `Memory.Allocator` is allocation *strategy*, not storage

---

### 8. Relationship Between Memory and Storage

The current split between `memory-primitives` (Tier 10) and `storage-primitives` (Tier 12) reflects:

| Package | Concern | Abstraction Level |
|---------|---------|-------------------|
| memory-primitives | Raw bytes | Untyped addresses |
| storage-primitives | Typed elements | Typed element storage |

**Proposal**: This split is academically sound. Memory is the *substrate*; Storage is *typed use* of that substrate.

```
Storage<Element>        ← Typed element storage
    uses
Memory.Address          ← Untyped byte addresses
Memory.Arena            ← Untyped bump allocator
Memory.Buffer           ← Untyped byte view
```

---

## Part IV: Proposed Redesign

### 9. Minimal Canonical Storage Taxonomy

Based on the analysis, the minimal academically defensible set:

```
Storage.Inline<Element, let capacity>   ← Embedded in container
Storage.Stack<Element>                  ← Scoped, LIFO lifetime
Storage.Heap<Element>                   ← Independent lifetime
Storage.Arena<Element>                  ← Bulk lifetime
Storage.Pool<Element>                   ← Slot recycling
Storage.View<Element>                   ← Non-owning reference
Storage.External<Element>               ← Runtime-managed
```

### 10. Typing Rules

Per [RES-024], Tier 3 research requires formal semantics.

#### 10.1 Ownership Predicates

```
Γ ⊢ s : Storage.Inline<T, N>   →  Γ owns s exclusively
Γ ⊢ s : Storage.Heap<T>        →  Γ owns s, may share via ARC
Γ ⊢ s : Storage.Arena<T>       →  Γ owns s, bulk free only
Γ ⊢ s : Storage.View<T>        →  Γ borrows from source
```

#### 10.2 Lifetime Rules

```
Storage.Inline:   lifetime(s) = lifetime(container)
Storage.Stack:    lifetime(s) = lexical scope
Storage.Heap:     lifetime(s) = ARC refcount > 0
Storage.Arena:    lifetime(s) = until arena.reset()
Storage.Pool:     lifetime(s) = until slot recycled
Storage.View:     lifetime(s) ≤ lifetime(source)
Storage.External: lifetime(s) = managed externally
```

#### 10.3 Access Rules

```
Storage.Inline:   access(s) iff container accessible
Storage.Heap:     access(s) iff reference held
Storage.View:     access(s) iff borrow valid
Storage.External: access(s) iff external system permits
```

---

### 11. Migration from Current Implementation

#### Phase 1: Reclassify Existing Components

| Current | Becomes | Rationale |
|---------|---------|-----------|
| `Storage<Element>` | `Storage.Heap<Element>` | Clarify lifetime discipline |
| `Storage.Static<N>` | `Storage.Inline<Element, N>` | Clarify placement |
| `Storage.Ring` | Move to buffer-primitives | Access discipline, not storage |
| `Storage.Heap.Header.*` | Separate namespace | Metadata, not storage |

#### Phase 2: Add Missing Primitives

| New | Source |
|-----|--------|
| `Storage.View<Element>` | Wrap `Span<Element>` semantics |
| `Storage.Arena<Element>` | Typed wrapper over `Memory.Arena` |
| `Storage.Pool<Element>` | Extract from `Storage.Heap.Header.Arena` |
| `Storage.External<Element>` | For MMIO, GPU, etc. |

#### Phase 3: Establish Formal Boundaries

- Storage primitives define *existence*
- Buffer primitives define *access patterns*
- ADT packages define *semantics*

---

## Part V: Open Questions

### 12. Questions Requiring Further Research

| ID | Question | Status |
|----|----------|--------|
| Q1 | Should `Storage.Stack` be distinct from `Storage.Inline`? | Swift's stack promotion may make them equivalent |
| Q2 | Should `Storage.Pool` be in storage-primitives or a separate package? | Depends on whether it's fundamental or derived |
| Q3 | How does `Storage.External` interact with `~Copyable`? | Needs investigation of MMIO patterns |
| Q4 | Should headers be part of storage types or separate? | Current design separates; validate this |
| Q5 | Tier placement: Should storage move lower than Tier 12? | Original design proposed Tier 2 |

---

## Outcome

**Status**: IN_PROGRESS

**Next Steps**:

1. **Validate with ChatGPT**: Collaborative discussion per [COLLAB-*]
2. **Formal semantics**: Complete typing rules per [RES-024]
3. **Swift-specific constraints**: Identify what Swift's type system can/cannot express
4. **Prototype implementation**: Verify design compiles and works

---

## References

### Foundational Papers

1. Girard, J.-Y. (1987) "Linear logic" - Theoretical Computer Science 50: 1-102
2. Wadler, P. (1990) "Linear Types Can Change the World!" - IFIP TC 2
3. Tofte, M. & Talpin, J.-P. (1997) "Region-Based Memory Management" - Information and Computation 132
4. Clarke, D., Potter, J., & Noble, J. (1998) "Ownership Types for Flexible Alias Protection" - OOPSLA
5. Reynolds, J.C. (2002) "Separation Logic: A Logic for Shared Mutable Data Structures" - LICS
6. Boyland, J. (2003) "Checking Interference with Fractional Permissions" - SAS
7. Walker, D. (2005) "Substructural Type Systems" - ATTAPL

### Modern Formalizations

8. Jung, R. et al. (2018) "RustBelt: Securing the Foundations of the Rust Programming Language" - POPL
9. Weiss, A. et al. (2019-2021) "Oxide: The Essence of Rust" - arXiv
10. Pearce, D. (2021) "A Lightweight Formalism for Reference Lifetimes and Borrowing in Rust" - TOPLAS

### Systems Research

11. Bonwick, J. (1994) "The Slab Allocator: An Object-Caching Kernel Memory Allocator" - USENIX Summer
12. Grossman, D. et al. (2002) "Region-Based Memory Management in Cyclone" - PLDI
13. Boyapati, C. et al. (2003) "Ownership Types for Safe Region-Based Memory Management in Real-Time Java" - PLDI

### Surveys

14. Tofte, M. et al. (2004) "A Retrospective on Region-Based Memory Management" - Higher-Order and Symbolic Computation
15. Clarke, D. et al. (2013) "Ownership Types: A Survey" - Aliasing in OOP

### Prior Swift Primitives Research

16. `/Users/coen/Developer/swift-primitives/Research/storage-primitives-design.md`
17. `/Users/coen/Developer/swift-primitives/Research/unified-storage-primitive.md`
18. `/Users/coen/Developer/swift-primitives/Research/inline-storage-read-pointer-escape.md`
