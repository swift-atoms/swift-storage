# Storage Primitives Canonical API

<!--
---
version: 1.0.0
last_updated: 2026-02-03
status: IN_PROGRESS
applies_to: [swift-storage-primitives]
normative: true
---
-->

## Purpose

Define the theoretically perfect public API for storage-primitives, derived from:
- The synthesis document (storage-ownership-reference-synthesis.md)
- The axis-ownership policy
- [API-NAME-001] Nest.Name pattern
- [API-NAME-002] No compound identifiers
- [API-IMPL-005] One type per file
- [API-IMPL-008] Minimal type body

This API is agnostic to downstream consumers. It is derived purely from what storage primitives MUST provide based on their position in the abstraction stack.

---

## Design Principle

Storage is the **coordination layer** between raw memory and buffers/ADTs. What distinguishes it from raw allocation:

| Capability | Raw allocation | Storage primitive |
|------------|---------------|-------------------|
| Typed element access | Yes | Yes |
| Initialization tracking | No | Yes |
| Physical coordinate system | No | Yes |
| Span-based lifecycle | No | Yes |
| Safe deinit (only initialized slots) | No | Yes |
| Bulk move/copy/deinitialize | No | Yes |

**Storage speaks only in `Storage.Slot` and `Storage.Span`.**

Storage does NOT know about:
- `Index<Element>` — logical ADT positions (buffer/ADT layer maps these to slots)
- `Range.Lazy<Index<Element>>` — above storage's abstraction
- Ring buffer discipline — buffer layer concern
- Element shifting after removal — ADT layer concern
- Growth policy — ADT layer concern

---

## Type Inventory

### Core Types (Storage Primitives Core module)

| Type | Kind | File |
|------|------|------|
| `Storage` | `enum` (namespace) | `Storage.swift` |
| `Storage.Slot` | `typealias` = `Tagged<Storage, Ordinal>` | `Storage.Slot.swift` |
| `Storage.Span` | `struct` | `Storage.Span.swift` |
| `Storage.Initialization` | `enum` | `Storage.Initialization.swift` |
| `Storage.Heap<Element: ~Copyable>` | `final class` | `Storage.Heap.swift` |
| `Storage.Heap<Element>.Header` | `struct` | `Storage.Heap.Header.swift` |
| `Storage.Inline<Element: ~Copyable, let capacity: Int>` | `struct: ~Copyable` | `Storage.Inline.swift` |
| `Storage.Inline<Element, capacity>.Error` | `enum` | `Storage.Inline.Error.swift` |

### REMOVED from current implementation

| Type/API | Reason | Moves To |
|----------|--------|----------|
| `Storage.Shift` | Element shifting is ADT concern | buffer-primitives or ADT |
| All `Index<Element>` parameters | Storage speaks in Slot, not Index | buffer/ADT layer |
| All `Range.Lazy<Index<Element>>` parameters | Above storage abstraction | buffer/ADT layer |
| `forEach(count:_:)` | Iteration is buffer/ADT concern | buffer-primitives |
| `withElement(at:_:)` | Index-based element access | buffer-primitives |
| `withMutableElement(at:_:)` | Index-based mutable access | buffer-primitives |
| `deinitialize(head:count:)` | Ring buffer awareness | buffer-primitives |
| `shift.left(removedAt:count:)` | Collection operation | ADT layer |
| `Affine.Discrete.Ratio<Storage, Memory>.stride` | Move to Inline module | Storage Inline Primitives |

---

## Canonical API

### Storage (namespace)

```swift
// File: Storage.swift
public enum Storage {}
```

---

### Storage.Slot

```swift
// File: Storage.Slot.swift
extension Storage {
    /// Physical slot coordinate in storage [0, capacity).
    ///
    /// All storage APIs accept Storage.Slot, never Index<Element>.
    /// Buffer disciplines map logical indices to physical slots.
    public typealias Slot = Tagged<Storage, Ordinal>
}
```

Inherits from `Tagged<Storage, Ordinal>`:
- `Storage.Slot.Count` — count of slots
- `Storage.Slot.Offset` — distance between slots

---

### Storage.Span

```swift
// File: Storage.Span.swift
extension Storage {
    /// Contiguous range of physical slots [start, end).
    public struct Span: Sendable, Equatable {
        public let start: Slot
        public let end: Slot

        public init(start: Slot, end: Slot)
        public init(start: Storage.Slot, count: Storage.Slot.Count)
    }
}

// Computed properties
extension Storage.Span {
    public var isEmpty: Bool
    public var count: Storage.Slot.Count
}

// Factory
extension Storage.Span {
    public static var empty: Self
}
```

No changes from current. This is correct.

---

### Storage.Initialization

```swift
// File: Storage.Initialization.swift
extension Storage {
    /// Which physical slots contain initialized elements.
    ///
    /// Invariants for .two:
    /// - first.start < second.start
    /// - first.end <= second.start
    public enum Initialization: Sendable, Equatable {
        case empty
        case one(Span)
        case two(first: Span, second: Span)
    }
}

// Computed properties
extension Storage.Initialization {
    public var count: Storage.Slot.Count
    public var isEmpty: Bool
}

// Factory
extension Storage.Initialization {
    public static func linear(count: Storage.Slot.Count) -> Self
}
```

No changes from current. This is correct.

---

### Storage.Heap

```swift
// File: Storage.Heap.swift (in Core module)
extension Storage {
    /// Heap-allocated typed element storage.
    ///
    /// Backed by ManagedBuffer with ARC lifetime management.
    /// Tracks initialization state for safe deinit.
    public final class Heap<Element: ~Copyable>: ManagedBuffer<Heap<Element>.Header, Element> {
        deinit { /* iterates initialization spans */ }
    }
}
```

#### Storage.Heap.Header

```swift
// File: Storage.Heap.Header.swift (in Core module)
extension Storage.Heap where Element: ~Copyable {
    /// ManagedBuffer header tracking initialization state.
    public struct Header: Sendable {
        public var initialization: Storage.Initialization

        public init(initialization: Storage.Initialization = .empty)
    }
}

extension Storage.Heap.Header {
    public var count: Storage.Slot.Count
    public var isEmpty: Bool
}
```

No changes from current. This is correct.

#### Storage.Heap — Factory

```swift
// File: Storage.Heap ~Copyable.swift (in Heap module)
extension Storage.Heap where Element: ~Copyable {
    /// Creates storage with the specified minimum slot capacity.
    public static func create(
        minimumCapacity: Storage.Slot.Count
    ) -> Storage.Heap<Element>
}
```

#### Storage.Heap — Properties

```swift
extension Storage.Heap where Element: ~Copyable {
    /// The initialization state describing which slots are initialized.
    public var initialization: Storage.Initialization { get set }

    /// Storage capacity in slot count.
    public var slotCapacity: Storage.Slot.Count { get }
}
```

> **Note on `slotCapacity`**: This name exists because `ManagedBuffer.capacity` returns `Int`.
> Storage speaks in `Storage.Slot.Count`. The name distinguishes the typed accessor
> from the inherited untyped one.

#### Storage.Heap — Fundamental Slot Access

```swift
extension Storage.Heap where Element: ~Copyable {
    /// Returns a mutable pointer to the element at the given physical slot.
    @unsafe
    public func pointer(at slot: Storage.Slot) -> UnsafeMutablePointer<Element>

    /// Initializes storage at the given physical slot.
    /// Caller is responsible for updating initialization state.
    public func initialize(to element: consuming Element, at slot: Storage.Slot)

    /// Moves the element at the given physical slot, deinitializing that slot.
    /// Caller is responsible for updating initialization state.
    public func move(at slot: Storage.Slot) -> Element

    /// Deinitializes (destroys) the element at the given physical slot.
    /// Caller is responsible for updating initialization state.
    public func deinitialize(at slot: Storage.Slot)
}
```

> These are `func` (not `mutating func`) because Heap is a class.

#### Storage.Heap — Span Operations

```swift
extension Storage.Heap where Element: ~Copyable {
    /// Deinitializes all elements in the given span.
    /// Caller is responsible for updating initialization state.
    public func deinitialize(span: Storage.Span)

    /// Deinitializes all tracked initialized slots and resets initialization to .empty.
    public func deinitialize()

    /// Moves elements from a span to linear positions in the destination.
    /// Caller is responsible for updating initialization state on both storages.
    public func move(span: Storage.Span, to destination: Storage.Heap<Element>)

    /// Provides read-only Span<Element> access to elements in the slot range.
    public func withSpan<R, E: Swift.Error>(
        _ span: Storage.Span,
        _ body: (Span<Element>) throws(E) -> R
    ) throws(E) -> R
}
```

> `deinitialize()` (no args) iterates `initialization` and handles all three
> cases (.empty, .one, .two), then resets to .empty. This is the same logic
> as deinit, but callable explicitly.

#### Storage.Heap — Copyable Extensions

```swift
// File: Storage.Heap Copyable.swift (in Heap module)
extension Storage.Heap where Element: Copyable {
    /// Creates a new storage with copies of all initialized elements.
    public func copy() -> Storage.Heap<Element>

    /// Copies all initialized elements to destination storage.
    public func copy(to destination: Storage.Heap<Element>)

    /// Copies elements in span to linear positions in destination.
    public func copy(span: Storage.Span, to destination: Storage.Heap<Element>)
}
```

---

### Storage.Inline

```swift
// File: Storage.Inline.swift (in Core module)
extension Storage {
    /// Fixed-capacity inline storage with 64-byte slots.
    ///
    /// Stack-allocated. No heap allocation. Supports ~Copyable elements.
    /// 64-byte slot layout prevents dense Span access — use pointer(at:) instead.
    public struct Inline<Element: ~Copyable, let capacity: Int>: ~Copyable {
        @usableFromInline
        package var _storage: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

        @usableFromInline
        package var _initialization: Initialization

        @inlinable
        public init() throws(Error)
    }
}

extension Storage.Inline: Copyable where Element: Copyable {}
extension Storage.Inline: Sendable where Element: Sendable {}
```

#### Storage.Inline.Error

```swift
// File: Storage.Inline.Error.swift (in Core module)
extension Storage.Inline where Element: ~Copyable {
    public enum Error: Swift.Error, Sendable {
        case strideExceedsSlotSize(stride: Int, maxSlotSize: Int)
        case alignmentExceedsStorageAlignment(alignment: Int, maxAlignment: Int)
    }
}
```

#### Storage.Inline — Properties

```swift
// File: Storage.Inline ~Copyable.swift (in Inline module)
extension Storage.Inline where Element: ~Copyable {
    /// The initialization state tracking which slots are initialized.
    public var initialization: Storage.Initialization { get set }
}
```

#### Storage.Inline — Fundamental Slot Access

```swift
extension Storage.Inline where Element: ~Copyable {
    /// Returns an immutable pointer to the element at the given physical slot.
    /// Non-mutating: valid in _read accessors where self is borrowed.
    @unsafe
    @_lifetime(borrow self)
    public func pointer(at slot: Storage.Slot) -> UnsafePointer<Element>

    /// Returns a mutable pointer to the element at the given physical slot.
    @unsafe
    public mutating func pointer(at slot: Storage.Slot) -> UnsafeMutablePointer<Element>

    /// Initializes storage at the given physical slot.
    /// Caller is responsible for updating initialization state.
    public mutating func initialize(to element: consuming Element, at slot: Storage.Slot)

    /// Moves the element at the given physical slot, deinitializing that slot.
    /// Caller is responsible for updating initialization state.
    public mutating func move(at slot: Storage.Slot) -> Element

    /// Deinitializes (destroys) the element at the given physical slot.
    /// Non-mutating to allow use from deinit-like contexts.
    /// Caller is responsible for updating initialization state.
    public func deinitialize(at slot: Storage.Slot)
}
```

> Inline has two `pointer(at:)` overloads (immutable non-mutating vs mutable mutating)
> because Inline is a struct. The mutability of the pointer follows the mutability
> of `self`. Heap only needs one (always mutable, because Heap is a class).

#### Storage.Inline — Span Operations

```swift
extension Storage.Inline where Element: ~Copyable {
    /// Deinitializes all elements in the given span.
    /// Non-mutating to allow use from deinit-like contexts.
    public func deinitialize(span: Storage.Span)

    /// Deinitializes all tracked initialized slots and resets initialization to .empty.
    public mutating func deinitialize()
}
```

> Inline's `deinitialize()` is `mutating` because it resets `_initialization`.
> Heap's `deinitialize()` is `func` because Heap is a class.

#### Storage.Inline — Cross-Storage Operations

```swift
extension Storage.Inline where Element: ~Copyable {
    /// Moves elements in span to linear positions in destination heap storage.
    public mutating func move(span: Storage.Span, to destination: Storage.Heap<Element>)
}
```

#### Storage.Inline — Copyable Extensions

```swift
// File: Storage.Inline Copyable.swift (in Inline module)
extension Storage.Inline where Element: Copyable {
    /// Copies elements in span to linear positions in destination heap storage.
    public func copy(span: Storage.Span, to destination: Storage.Heap<Element>)
}
```

---

## File Organization

### Storage Primitives Core (module)

| File | Contents |
|------|----------|
| `Storage.swift` | `public enum Storage {}` — namespace only |
| `Storage.Slot.swift` | `Storage.Slot` typealias |
| `Storage.Span.swift` | `Storage.Span` struct + computed properties + factory |
| `Storage.Initialization.swift` | `Storage.Initialization` enum + computed properties + factory |
| `Storage.Heap.swift` | `Storage.Heap<Element>` class declaration + deinit |
| `Storage.Heap.Header.swift` | `Storage.Heap.Header` struct + computed properties |
| `Storage.Inline.swift` | `Storage.Inline<Element, capacity>` struct + init + conditional conformances |
| `Storage.Inline.Error.swift` | `Storage.Inline.Error` enum |
| `exports.swift` | Re-exports: Index_Primitives, Range_Primitives, Memory_Primitives |

### Storage Heap Primitives (module)

| File | Contents |
|------|----------|
| `Storage.Heap ~Copyable.swift` | Factory, properties, slot access, span operations |
| `Storage.Heap Copyable.swift` | copy(), copy(to:), copy(span:to:) |
| `exports.swift` | Re-exports: Storage_Primitives_Core, Property_Primitives |

### Storage Inline Primitives (module)

| File | Contents |
|------|----------|
| `Storage.Inline ~Copyable.swift` | Properties, slot access, span operations, cross-storage move |
| `Storage.Inline Copyable.swift` | copy(span:to:) |
| `Affine.Discrete.Ratio+Storage.swift` | `.stride = 64` (moved from Core) |
| `exports.swift` | Re-exports: Storage_Primitives_Core, Property_Primitives |

### Storage Primitives (umbrella module)

| File | Contents |
|------|----------|
| `exports.swift` | Re-exports: Storage_Primitives_Core, Storage_Heap_Primitives, Storage_Inline_Primitives |

---

## Current vs Proposed: Diff Summary

### Storage.Heap API changes

| Current | Proposed | Change |
|---------|----------|--------|
| `pointer(at index: Index<Element>)` | — | REMOVE |
| `initialize(to:at index: Index<Element>)` | — | REMOVE |
| `move(at index: Index<Element>)` | — | REMOVE |
| `withSpan(count: Index<Element>.Count, _:)` | — | REMOVE |
| `withSpan(_:)` (no args, uses tracked count) | — | REMOVE (use span-based) |
| `deinitialize(count: Index<Element>.Count)` | — | REMOVE |
| `deinitialize()` (delegates to count-based) | `deinitialize()` (iterates initialization) | CHANGE implementation |
| `move(to:count: Index<Element>.Count)` | — | REMOVE |
| `move(to:)` (no args, uses tracked count) | — | REMOVE |
| `deinitialize(in range: Range.Lazy<Index<Element>>)` | — | REMOVE |
| — | `copy(span:to:)` | ADD |

### Storage.Inline API changes

| Current | Proposed | Change |
|---------|----------|--------|
| `pointer(at index: Index<Element>) -> UnsafePointer` | — | REMOVE |
| `pointer(at index: Index<Element>) -> UnsafeMutablePointer` | — | REMOVE |
| `initialize(to:at index: Index<Element>)` | — | REMOVE |
| `move(at index: Index<Element>)` | — | REMOVE |
| `forEach(count:_:)` | — | REMOVE |
| `withElement(at index:_:)` | — | REMOVE |
| `withMutableElement(at index:_:)` | — | REMOVE |
| `deinitialize(count: Index<Element>.Count)` | — | REMOVE |
| `deinitialize(in range: Range.Lazy<Index<Element>>)` | — | REMOVE |
| `deinitialize(head:count:)` | — | REMOVE (ring buffer = buffer layer) |
| `deinitializeAll()` | `deinitialize()` | RENAME (consistent with Heap) |
| `move(to:count: Index<Element>.Count)` | `move(span:to:)` | CHANGE parameter |
| `copy(to:count: Index<Element>.Count)` | `copy(span:to:)` | CHANGE parameter |
| `shift` property + `Storage.Shift` type | — | REMOVE (ADT concern) |
| — | `deinitialize(at slot:)` | ADD |
| — | `deinitialize(span:)` | ADD |

### File changes

| Current | Proposed | Change |
|---------|----------|--------|
| `Storage.swift` (Heap + Inline + conformances) | `Storage.swift` (namespace only) | SPLIT |
| — | `Storage.Heap.swift` (class + deinit) | NEW |
| — | `Storage.Inline.swift` (struct + init + conformances) | NEW |
| — | `Storage.Inline.Error.swift` | NEW |
| `Storage.Shift.swift` | — | REMOVE |
| `Affine.Discrete.Ratio Storage Memory.swift` | `Affine.Discrete.Ratio+Storage.swift` (in Inline module) | MOVE + RENAME |

---

## Naming Compliance Audit

### [API-NAME-001] Nest.Name — All PASS

| Type | Pattern | Valid |
|------|---------|-------|
| `Storage` | Domain | ✓ |
| `Storage.Heap` | Domain.Variant | ✓ |
| `Storage.Inline` | Domain.Variant | ✓ |
| `Storage.Slot` | Domain.Coordinate | ✓ |
| `Storage.Span` | Domain.Range | ✓ |
| `Storage.Initialization` | Domain.State | ✓ |
| `Storage.Heap.Header` | Domain.Variant.Metadata | ✓ |
| `Storage.Inline.Error` | Domain.Variant.Error | ✓ |

### [API-NAME-002] No Compound Identifiers — Audit

| Identifier | Compound? | Verdict |
|------------|-----------|---------|
| `slotCapacity` | Yes (slot + capacity) | ACCEPT — distinguishes from inherited `capacity: Int` |
| `deinitialize` | No (single verb) | ✓ |
| `initialize` | No (single verb) | ✓ |
| `withSpan` | No (preposition + noun) | ✓ |

### [API-IMPL-005] One Type Per File — REQUIRES CHANGE

Current `Storage.swift` contains Storage + Heap + Inline. Split into three files.

### [API-IMPL-008] Minimal Type Body — All PASS

| Type | Body Contains | Valid |
|------|--------------|-------|
| `Storage.Heap` | deinit only (class) | ✓ |
| `Storage.Inline` | stored properties + init + Error nested type | ✓ (~Copyable exception) |
| `Storage.Span` | stored properties + init | ✓ |
| `Storage.Heap.Header` | stored properties + init | ✓ |

---

## Complete Public API Surface (Final)

### Storage.Slot

```
Storage.Slot                              typealias = Tagged<Storage, Ordinal>
Storage.Slot.Count                        (inherited)
Storage.Slot.Offset                       (inherited)
```

### Storage.Span

```
Storage.Span.init(start:end:)             init
Storage.Span.init(start:count:)           init
Storage.Span.isEmpty                      computed property
Storage.Span.count                        computed property
Storage.Span.empty                        static factory
```

### Storage.Initialization

```
Storage.Initialization.empty              case
Storage.Initialization.one(Span)          case
Storage.Initialization.two(first:second:) case
Storage.Initialization.count              computed property
Storage.Initialization.isEmpty            computed property
Storage.Initialization.linear(count:)     static factory
```

### Storage.Heap

```
Storage.Heap.create(minimumCapacity:)     static factory
Storage.Heap.initialization               stored property (via header)
Storage.Heap.slotCapacity                 computed property
Storage.Heap.pointer(at:)                 slot → UnsafeMutablePointer
Storage.Heap.initialize(to:at:)           slot-based
Storage.Heap.move(at:)                    slot-based
Storage.Heap.deinitialize(at:)            slot-based
Storage.Heap.deinitialize(span:)          span-based
Storage.Heap.deinitialize()               tracked initialization
Storage.Heap.move(span:to:)              span → destination
Storage.Heap.withSpan(_:_:)              span → Span<Element> closure
Storage.Heap.copy()                       → new Heap (Copyable)
Storage.Heap.copy(to:)                    → existing Heap (Copyable)
Storage.Heap.copy(span:to:)              partial copy (Copyable)
```

### Storage.Heap.Header

```
Storage.Heap.Header.init(initialization:) init
Storage.Heap.Header.initialization        stored property
Storage.Heap.Header.count                 computed property
Storage.Heap.Header.isEmpty               computed property
```

### Storage.Inline

```
Storage.Inline.init()                     throws(Error)
Storage.Inline.initialization             stored property
Storage.Inline.pointer(at:) → Unsafe      non-mutating, immutable
Storage.Inline.pointer(at:) → UnsafeMut   mutating, mutable
Storage.Inline.initialize(to:at:)         slot-based, mutating
Storage.Inline.move(at:)                  slot-based, mutating
Storage.Inline.deinitialize(at:)          slot-based, non-mutating
Storage.Inline.deinitialize(span:)        span-based, non-mutating
Storage.Inline.deinitialize()             tracked, mutating
Storage.Inline.move(span:to:)            → Heap, mutating
Storage.Inline.copy(span:to:)            → Heap (Copyable)
```

### Storage.Inline.Error

```
Storage.Inline.Error.strideExceedsSlotSize(stride:maxSlotSize:)
Storage.Inline.Error.alignmentExceedsStorageAlignment(alignment:maxAlignment:)
```

**Total public API surface: 38 members across 8 types.**
