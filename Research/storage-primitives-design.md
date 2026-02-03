# Storage Primitives Design

<!--
---
version: 1.0.0
last_updated: 2026-01-26
status: IN_PROGRESS
tier: 3
---
-->

## Context

Research into ring buffer index placement revealed broader architectural need: multiple data structure packages (Array, Stack, Queue, Deque, List, Buffer) have ad-hoc `*.Storage` types with duplicated patterns. A unified `storage-primitives` package would:

1. Provide typed ring buffer index operations (original question)
2. Consolidate storage layout abstractions
3. Reduce duplication across 6+ packages
4. Enable consistent typed-index adoption

**Trigger**: Ring buffer index placement question escalated to architectural scope.

---

## Proposed Package

**Name**: `swift-storage-primitives`

**Tier**: 2 (depends on Tier 0-1 only)

**Dependencies**:
- `swift-index-primitives` (Tier 1) - for typed indices
- `swift-affine-primitives` (Tier 0) - transitive via index-primitives

**Dependents** (packages that would use storage-primitives):
- `swift-array-primitives` (Tier 7)
- `swift-stack-primitives` (Tier 9)
- `swift-queue-primitives` (Tier 10)
- `swift-deque-primitives` (Tier 9)
- `swift-list-primitives` (Tier 9)
- `swift-buffer-primitives` (Tier 10)

---

## Proposed Structure

```
swift-storage-primitives/
├── Package.swift
├── Sources/
│   └── Storage Primitives/
│       ├── Storage.swift                      # Namespace
│       │
│       ├── Storage.Layout.swift               # Layout enum
│       ├── Storage.Layout.Contiguous.swift    # Linear storage pattern
│       ├── Storage.Layout.Ring.swift          # Circular buffer pattern
│       ├── Storage.Layout.Arena.swift         # Index-based node storage
│       │
│       ├── Storage.Heap.Header.swift               # Header namespace
│       ├── Storage.Heap.Header.Count.swift         # Single count header
│       ├── Storage.Heap.Header.Ring.swift          # head/tail/count header
│       ├── Storage.Heap.Header.Arena.swift         # head/tail/freeHead/count header
│       │
│       ├── Index+Ring.swift                   # Ring buffer index operations
│       ├── Index+Contiguous.swift             # Contiguous index operations
│       │
│       └── exports.swift
└── Tests/
```

---

## Component Specifications

### 1. Storage Namespace

```swift
// Storage.swift

/// Namespace for storage-related primitives.
///
/// Storage primitives provide fundamental abstractions for how data structures
/// organize their backing storage. These patterns are shared across Array, Stack,
/// Queue, Deque, List, and Buffer implementations.
///
/// ## Storage Layouts
///
/// - ``Storage/Layout/Contiguous``: Linear sequential storage (Array, Stack)
/// - ``Storage/Layout/Ring``: Circular buffer storage (Queue, Deque)
/// - ``Storage/Layout/Arena``: Index-based node storage (List)
///
/// ## Headers
///
/// - ``Storage/Header/Count``: Single count tracking
/// - ``Storage/Header/Ring``: Head/tail/count for ring buffers
/// - ``Storage/Header/Arena``: Head/tail/freeHead/count for arenas
public enum Storage {}
```

---

### 2. Storage Layouts

```swift
// Storage.Layout.swift

extension Storage {
    /// Classification of storage organization strategies.
    ///
    /// Each layout has distinct index arithmetic and capacity semantics.
    public enum Layout {
        /// Linear sequential storage where elements occupy positions 0..<count.
        /// Used by Array, Stack.
        case contiguous

        /// Circular buffer where elements wrap around capacity boundary.
        /// Used by Queue, Deque.
        case ring

        /// Index-based node storage with free-list allocation.
        /// Used by List.Linked.
        case arena
    }
}
```

---

### 3. Ring Buffer Index Operations

```swift
// Index+Ring.swift

import Index_Primitives

extension Storage {
    /// Ring buffer index operations.
    ///
    /// These operations provide modular arithmetic for circular buffer navigation.
    /// All operations maintain the invariant that results are in `0..<capacity`.
    public enum Ring {}
}

extension Storage.Ring {
    /// Advances an index by one position, wrapping at capacity.
    ///
    /// - Parameters:
    ///   - index: The current index.
    ///   - capacity: The buffer capacity (must be positive).
    /// - Returns: The successor index wrapped to `0..<capacity`.
    /// - Complexity: O(1)
    @inlinable
    public static func successor<Element: ~Copyable>(
        of index: Index<Element>,
        wrapping capacity: Index<Element>.Count
    ) -> Index<Element> {
        Index(__unchecked: (), position: (index.position.rawValue + 1) % capacity.rawValue)
    }

    /// Retreats an index by one position, wrapping at capacity.
    ///
    /// - Parameters:
    ///   - index: The current index.
    ///   - capacity: The buffer capacity (must be positive).
    /// - Returns: The predecessor index wrapped to `0..<capacity`.
    /// - Complexity: O(1)
    @inlinable
    public static func predecessor<Element: ~Copyable>(
        of index: Index<Element>,
        wrapping capacity: Index<Element>.Count
    ) -> Index<Element> {
        Index(__unchecked: (), position: (index.position.rawValue - 1 + capacity.rawValue) % capacity.rawValue)
    }

    /// Advances an index by an offset, wrapping at capacity.
    ///
    /// - Parameters:
    ///   - index: The starting index.
    ///   - offset: The offset to advance by (can be negative).
    ///   - capacity: The buffer capacity (must be positive).
    /// - Returns: The resulting index wrapped to `0..<capacity`.
    /// - Complexity: O(1)
    @inlinable
    public static func advanced<Element: ~Copyable>(
        _ index: Index<Element>,
        by offset: Index<Element>.Offset,
        wrapping capacity: Index<Element>.Count
    ) -> Index<Element> {
        let cap = capacity.rawValue
        let raw = (index.position.rawValue + offset.rawValue % cap + cap) % cap
        return Index(__unchecked: (), position: raw)
    }

    /// Calculates the physical index from a logical index in a ring buffer.
    ///
    /// Converts a logical index (0 = front of queue) to a physical storage position
    /// given the current head position.
    ///
    /// - Parameters:
    ///   - logicalIndex: The logical index (0..<count).
    ///   - head: The physical position of the first element.
    ///   - capacity: The buffer capacity.
    /// - Returns: The physical storage index.
    /// - Complexity: O(1)
    @inlinable
    public static func physicalIndex<Element: ~Copyable>(
        forLogical logicalIndex: Index<Element>,
        head: Index<Element>,
        capacity: Index<Element>.Count
    ) -> Index<Element> {
        Index(__unchecked: (), position: (head.position.rawValue + logicalIndex.position.rawValue) % capacity.rawValue)
    }
}

// MARK: - Extension on Index for ergonomic access

extension Tagged where RawValue == Affine.Discrete.Position, Tag: ~Copyable {
    /// Returns the next index, wrapping around at the given capacity.
    ///
    /// - Parameter capacity: The buffer capacity (must be positive).
    /// - Returns: The successor index wrapped to `0..<capacity`.
    @inlinable
    public func successor(wrapping capacity: Count) -> Self {
        Storage.Ring.successor(of: self, wrapping: capacity)
    }

    /// Returns the previous index, wrapping around at the given capacity.
    ///
    /// - Parameter capacity: The buffer capacity (must be positive).
    /// - Returns: The predecessor index wrapped to `0..<capacity`.
    @inlinable
    public func predecessor(wrapping capacity: Count) -> Self {
        Storage.Ring.predecessor(of: self, wrapping: capacity)
    }

    /// Returns this index advanced by an offset, wrapped within capacity.
    ///
    /// - Parameters:
    ///   - offset: The offset to advance by.
    ///   - capacity: The buffer capacity.
    /// - Returns: The resulting index wrapped to `0..<capacity`.
    @inlinable
    public func advanced(by offset: Offset, wrapping capacity: Count) -> Self {
        Storage.Ring.advanced(self, by: offset, wrapping: capacity)
    }
}
```

---

### 4. Contiguous Index Operations

```swift
// Index+Contiguous.swift

import Index_Primitives

extension Storage {
    /// Contiguous storage index operations.
    ///
    /// Operations for linear sequential storage where elements occupy 0..<count.
    public enum Contiguous {}
}

extension Storage.Contiguous {
    /// Returns the next index without wrapping.
    ///
    /// - Parameter index: The current index.
    /// - Returns: The successor index.
    /// - Complexity: O(1)
    @inlinable
    public static func successor<Element: ~Copyable>(
        of index: Index<Element>
    ) -> Index<Element> {
        Index(__unchecked: (), position: index.position.rawValue + 1)
    }

    /// Returns the previous index without wrapping.
    ///
    /// - Parameter index: The current index.
    /// - Returns: The predecessor index.
    /// - Precondition: index.position > 0
    /// - Complexity: O(1)
    @inlinable
    public static func predecessor<Element: ~Copyable>(
        of index: Index<Element>
    ) -> Index<Element> {
        Index(__unchecked: (), position: index.position.rawValue - 1)
    }
}

// MARK: - Extension on Index for ergonomic access

extension Tagged where RawValue == Affine.Discrete.Position, Tag: ~Copyable {
    /// Returns the next index without bounds checking.
    @inlinable
    public func successor() -> Self {
        Storage.Contiguous.successor(of: self)
    }

    /// Returns the previous index without bounds checking.
    ///
    /// - Precondition: Position must be > 0.
    @inlinable
    public func predecessor() -> Self {
        Storage.Contiguous.predecessor(of: self)
    }
}
```

---

### 5. Header Types

```swift
// Storage.Heap.Header.Count.swift

import Index_Primitives

extension Storage {
    /// Namespace for storage header types.
    public enum Header {}
}

extension Storage.Heap.Header {
    /// Header for contiguous storage tracking only element count.
    ///
    /// Used by Array and Stack where elements are stored linearly.
    public struct Count<Element: ~Copyable>: ~Copyable {
        /// Number of valid elements in storage.
        public var count: Index<Element>.Count

        /// Creates a header with zero count.
        @inlinable
        public init() {
            self.count = .zero
        }

        /// Creates a header with the given count.
        @inlinable
        public init(count: Index<Element>.Count) {
            self.count = count
        }
    }
}
```

```swift
// Storage.Heap.Header.Ring.swift

import Index_Primitives

extension Storage.Heap.Header {
    /// Header for ring buffer storage.
    ///
    /// Tracks head (dequeue position), tail (enqueue position), and count.
    /// Used by Queue and Deque.
    ///
    /// ## Invariants
    ///
    /// - `count` reflects number of valid elements
    /// - Elements occupy physical positions from `head` to `(head + count - 1) % capacity`
    /// - `tail == (head + count) % capacity` when buffer is not full
    public struct Ring<Element: ~Copyable>: ~Copyable {
        /// Physical position of next element to dequeue.
        public var head: Index<Element>

        /// Physical position where next element will be enqueued.
        public var tail: Index<Element>

        /// Number of valid elements in the buffer.
        public var count: Index<Element>.Count

        /// Creates an empty ring buffer header.
        @inlinable
        public init() {
            self.head = .zero
            self.tail = .zero
            self.count = .zero
        }

        /// Creates a ring buffer header with specified values.
        @inlinable
        public init(head: Index<Element>, tail: Index<Element>, count: Index<Element>.Count) {
            self.head = head
            self.tail = tail
            self.count = count
        }

        /// Advances head after dequeue, wrapping at capacity.
        @inlinable
        public mutating func advanceHead(capacity: Index<Element>.Count) {
            head = head.successor(wrapping: capacity)
            count = Index<Element>.Count(count.rawValue - 1)
        }

        /// Advances tail after enqueue, wrapping at capacity.
        @inlinable
        public mutating func advanceTail(capacity: Index<Element>.Count) {
            tail = tail.successor(wrapping: capacity)
            count = Index<Element>.Count(count.rawValue + 1)
        }
    }
}
```

```swift
// Storage.Heap.Header.Arena.swift

import Index_Primitives

extension Storage.Heap.Header {
    /// Header for arena-based storage with free-list.
    ///
    /// Used by List.Linked for index-based node allocation.
    ///
    /// ## Free List Management
    ///
    /// Freed slots are linked via indices stored in the deallocated memory.
    /// `freeHead` points to the first free slot, or a sentinel value if none.
    public struct Arena<Element: ~Copyable>: ~Copyable {
        /// Index of first element in logical order.
        public var head: Index<Element>

        /// Index of last element in logical order.
        public var tail: Index<Element>

        /// Index of first free slot (for reuse).
        public var freeHead: Index<Element>

        /// Number of valid elements.
        public var count: Index<Element>.Count

        /// Total slots allocated.
        public var capacity: Index<Element>.Count

        /// Sentinel value indicating no free slots.
        public static var noFreeSlot: Index<Element> {
            Index(__unchecked: (), position: -1)
        }

        /// Creates an empty arena header.
        @inlinable
        public init() {
            self.head = Self.noFreeSlot
            self.tail = Self.noFreeSlot
            self.freeHead = Self.noFreeSlot
            self.count = .zero
            self.capacity = .zero
        }

        /// Creates an arena header with specified capacity.
        @inlinable
        public init(capacity: Index<Element>.Count) {
            self.head = Self.noFreeSlot
            self.tail = Self.noFreeSlot
            self.freeHead = Self.noFreeSlot
            self.count = .zero
            self.capacity = capacity
        }
    }
}
```

---

### 6. Index.Count Extension

The headers use `Index<Element>.Count` which needs to exist. Check if this is already in index-primitives:

```swift
// If not present, add to index-primitives or storage-primitives:

extension Tagged where RawValue == Affine.Discrete.Position, Tag: ~Copyable {
    /// Count type for this index, representing element counts.
    ///
    /// Provides type safety preventing confusion between counts of different element types.
    public struct Count: Hashable, Comparable, Sendable, ExpressibleByIntegerLiteral {
        public let rawValue: Int

        @inlinable
        public init(_ rawValue: Int) {
            self.rawValue = rawValue
        }

        @inlinable
        public init(integerLiteral value: Int) {
            self.rawValue = value
        }

        @inlinable
        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        public static var zero: Self { Self(0) }
    }
}
```

---

## Migration Path

### Phase 1: Create Package

1. Create `swift-storage-primitives` at Tier 2
2. Add dependency on `swift-index-primitives`
3. Implement `Storage.Ring` index operations
4. Implement `Storage.Contiguous` index operations
5. Implement `Storage.Heap.Header.*` types

### Phase 2: Migrate Ring Buffer Operations

1. Remove ring buffer section from `Index+Arithmetic.swift`
2. Add `import Storage_Primitives` to queue-primitives
3. Update Queue to use `Storage.Heap.Header.Ring<Element>`
4. Update Queue to use typed index operations

### Phase 3: Migrate Other Packages

1. **Array**: Adopt `Storage.Heap.Header.Count<Element>`
2. **Stack**: Adopt `Storage.Heap.Header.Count<Element>`, typed indices
3. **Deque**: Adopt `Storage.Heap.Header.Ring<Element>`
4. **List**: Adopt `Storage.Heap.Header.Arena<Element>`
5. **Buffer**: Adopt appropriate headers

### Phase 4: Future Extensions

Potential additions:
- `Storage.Inline<Element, let capacity: Int>` - shared inline storage pattern
- `Storage.ManagedBuffer` - wrapper simplifying ManagedBuffer usage
- `Storage.Growth` - growth strategy protocols

---

## Tier Impact Analysis

**Current Tiers**:
```
Tier 1:  index-primitives (21 dependents)
Tier 7:  array-primitives
Tier 9:  stack-primitives, deque-primitives, list-primitives
Tier 10: queue-primitives, buffer-primitives
Tier 12: memory-primitives
```

**With storage-primitives at Tier 2**:
```
Tier 1:  index-primitives
Tier 2:  storage-primitives (NEW) ← depends on index-primitives
Tier 7:  array-primitives ← can use storage-primitives
Tier 9:  stack, deque, list ← can use storage-primitives
Tier 10: queue, buffer ← can use storage-primitives
Tier 12: memory-primitives
```

All target packages can depend on Tier 2.

---

## Comparison with Alternatives

| Approach | Ring Ops Location | Header Location | Pros | Cons |
|----------|-------------------|-----------------|------|------|
| **storage-primitives** | Storage.Ring | Storage.Heap.Header.* | Unified, typed, reusable | New package |
| Keep in index-primitives | Index extension | Ad-hoc per package | No new deps | Semantic pollution |
| Per-package | Each package | Each package | No coordination | Duplication |

**Recommendation**: `storage-primitives` provides the cleanest architecture.

---

## Open Questions

1. **Should inline storage patterns be included?**
   - `InlineArray<capacity, Slot>` pattern is repeated
   - Could provide `Storage.Inline<Element, let capacity: Int>`
   - Risk: Too much abstraction?

2. **Should ManagedBuffer wrappers be included?**
   - Every package wraps ManagedBuffer similarly
   - Could provide `Storage.Heap<Header, Element>`
   - Risk: Over-generalization?

3. **Relationship to memory-primitives?**
   - memory-primitives has `Memory.Contiguous.Protocol`
   - Should storage-primitives define layout, memory-primitives define access?
   - Or merge concepts?

---

## References

- Research agent findings on Array, Stack, Queue, Deque, List, Buffer Storage types
- `/Users/coen/Developer/swift-primitives/Documentation.docc/Primitives Tiers.md`
- `/Users/coen/Developer/swift-primitives/swift-index-primitives/Sources/Index Primitives/Index.swift`
- `/Users/coen/Developer/swift-primitives/swift-queue-primitives/Sources/Queue Primitives Core/Queue.swift`
