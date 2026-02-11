// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Index_Primitives
public import Bit_Vector_Primitives

/// Namespace for storage primitives.
///
/// `Storage` provides four storage disciplines with different lifecycle contracts:
///
/// | Need | Choose | Lifecycle |
/// |------|--------|-----------|
/// | Automatic cleanup, contiguous elements | ``Storage/Heap`` | **Tracked** — range-based initialization tracking with automatic cleanup in `deinit` |
/// | Stack-allocated, fixed capacity ≤256 | ``Storage/Inline`` | **Auto-tracked** — per-slot bit-vector tracking with automatic cleanup in `deinit` |
/// | Dual-array with consumer-defined metadata | ``Storage/Split`` | **Metadata-driven** — no tracking; consumer interprets lane metadata to determine element validity |
/// | Pool allocation with per-slot reuse | ``Storage/Pool`` | **Bitmap-tracked** — per-slot bit-vector tracking with automatic cleanup in `deinit` |
///
/// And physical coordinate types for slot-based access:
/// - `Index<Element>`: Physical slot position (typed by element)
/// - `Swift.Range<Index<Element>>`: Contiguous slot range
/// - ``Storage/Initialization``: Which slots are initialized (Heap and Inline only)
public enum Storage<Element: ~Copyable> {
    
    /// Describes which physical slots are initialized.
    ///
    /// Storage deinit iterates these spans to clean up exactly the
    /// initialized slots, regardless of buffer discipline.
    ///
    /// ## Cases
    ///
    /// - `empty`: No slots are initialized
    /// - `one`: A single contiguous range of initialized slots
    /// - `two`: Two disjoint ranges (e.g., wrapped ring buffer)
    ///
    /// ## Invariants
    ///
    /// - `.two` spans are sorted by start: `first.start < second.start`
    /// - `.two` spans are disjoint: `first.end <= second.start`
    ///
    /// ## Example: Ring Buffer Wrapping
    ///
    /// A ring buffer with capacity 8, head at slot 6, and 5 elements:
    /// ```
    /// Slots: [0][1][2][3][4][5][6][7]
    /// Data:   X  X  X  -  -  -  X  X
    ///         └──┴──┘           └──┴── initialized
    /// ```
    /// Initialization: `.two(first: [0,3), second: [6,8))`
    public enum Initialization: Sendable, Equatable {
        /// No slots are initialized.
        case empty
        
        /// A single contiguous range of initialized slots.
        case one(Swift.Range<Index_Primitives.Index<Element>>)
        
        /// Two disjoint ranges of initialized slots.
        ///
        /// Invariants:
        /// - `first.start < second.start`
        /// - `first.end <= second.start`
        case two(first: Swift.Range<Index_Primitives.Index<Element>>, second: Swift.Range<Index_Primitives.Index<Element>>)
    }
    
    /// Canonical heap storage using ManagedBuffer.
    ///
    /// `Storage<Element>.Heap` is the primitive heap storage building block.
    /// It provides:
    /// - Contiguous element storage with ARC lifetime
    /// - Reference semantics with manual element lifecycle
    /// - Support for ~Copyable elements
    /// - Initialization tracking via ``Storage/Heap/Header``
    ///
    /// ## Initialization Tracking
    ///
    /// The storage tracks which slots are initialized via the `initialization`
    /// property. The deinit uses this information to correctly deinitialize
    /// only the initialized slots.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let storage = Storage<Int>.Heap.create(minimumCapacity: Index<Int>.Count(10))
    /// storage.initialize(to: 42, at: .zero)
    /// let value = storage.move(at: .zero)
    /// ```
    public final class Heap: ManagedBuffer<Storage.Heap.Header, Element> {
        deinit {
            deinitialize()
        }
        
        /// Deinitializes all elements in the given range.
        ///
        /// Uses bulk deinitialization for better performance on contiguous ranges.
        ///
        /// - Parameter range: The contiguous range of slots to deinitialize.
        /// - Precondition: All slots in the range must contain initialized elements.
        /// - Note: The caller is responsible for updating `initialization` state.
        @inlinable
        public func deinitialize(range: Swift.Range<Index<Element>>) {
            guard !range.isEmpty else { return }
            unsafe pointer(at: range.lowerBound).deinitialize(count: range.count)
        }
        
        /// Deinitializes all tracked initialized slots and resets initialization to .empty.
        ///
        /// Iterates the `initialization` state and deinitializes exactly those slots
        /// that are tracked as initialized.
        @inlinable
        public func deinitialize() {
            header.initialization.forEach { range in
                deinitialize(range: range)
            }
            header.initialization = .empty
        }
    }
    
    /// Fixed-capacity inline storage with automatic per-slot initialization tracking.
    ///
    /// Provides stack-allocated storage with compile-time capacity. Elements are
    /// stored inline without heap allocation, making this suitable for small,
    /// fixed-size collections.
    ///
    /// ## Capacity Constraint
    ///
    /// `Storage.Inline` supports capacities from 0 to 256. For larger capacities,
    /// use `Storage.Heap` instead.
    ///
    /// ## Layout
    ///
    /// Storage uses `@_rawLayout` for automatic optimal layout computation:
    /// - Size: `MemoryLayout<Element>.stride × capacity`
    /// - Alignment: `MemoryLayout<Element>.alignment`
    ///
    /// ## Per-Slot Initialization Tracking
    ///
    /// Uses a 256-bit vector to track which slots are initialized.
    /// Operations automatically update the tracking:
    /// - `initialize(to:at:)` sets the slot's bit
    /// - `move(at:)` clears the slot's bit
    /// - `deinitialize(at:)` clears the slot's bit
    /// - `deinit` iterates set bits to clean up only initialized slots
    ///
    /// This eliminates the footgun where callers had to manually manage state.
    ///
    /// ## Invariants
    ///
    /// - `capacity` is a compile-time constant in range `0...256`
    /// - `_slots` has 256 bits; only bits `0..<capacity` are semantically meaningful
    /// - Bit `i` is set iff slot `i` contains an initialized element
    ///
    /// ## Usage
    ///
    /// ```swift
    /// var storage = Storage<Int>.Inline<8>()
    /// storage.initialize(to: 42, at: .zero)
    /// let value = storage.move(at: .zero)
    /// // No manual state management needed — deinit handles cleanup automatically
    /// ```
    /// Fixed-capacity pool storage with O(1) allocate and deallocate.
    ///
    /// `Storage<Element>.Pool` is a reference-semantic pool allocator for typed elements.
    /// It provides:
    /// - O(1) allocation via virgin cursor + free list
    /// - O(1) deallocation via free list push
    /// - Per-slot reuse (LIFO free list)
    /// - Automatic element deinit in `deinit` (via bitmap iteration)
    /// - Reference semantics for conditional Copyability in buffer compositions
    /// - CoW support via `isKnownUniquelyReferenced` + `copy()`
    ///
    /// ## Design Pattern
    ///
    /// Implements the same typed sentinel + Bit.Vector + in-band free list pattern
    /// as `Memory.Pool`, but at the storage tier with typed pointers and reference
    /// semantics. See `Research/storage-pool-architecture.md` (DECISION).
    ///
    /// ## Free List Design
    ///
    /// Free slots store `Index<Element>` in-band via `storeBytes`/`load` on the
    /// deinitialized slot memory. The sentinel (`_capacity.map(Ordinal.init)`,
    /// one-past-last) marks end-of-list.
    ///
    /// Virgin slots (never allocated) are tracked by `_nextUnused` cursor,
    /// providing O(1) initialization (no free list pre-build).
    ///
    /// ## Invariants
    ///
    /// - `MemoryLayout<Element>.stride >= MemoryLayout<Index<Element>>.size` (in-band free list)
    /// - Capacity is fixed at construction, immutable
    /// - `0 <= allocated <= capacity`
    /// - Free list is acyclic and contained within `[0, _nextUnused)`
    /// - Bitmap bit `i` is set iff slot `i` contains an initialized element
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let pool = try Storage<Node>.Pool(capacity: Index<Node>.Count(64))
    /// let slot = try pool.allocate()
    /// pool.pointer(at: slot).initialize(to: node)
    /// // ... use ...
    /// _ = pool.pointer(at: slot).move()
    /// try pool.deallocate(at: slot)
    /// ```
    public final class Pool {

        // MARK: - Stored Properties

        /// Composed memory pool that manages raw slot storage, free list,
        /// virgin cursor, and allocation tracking.
        @usableFromInline
        package var _pool: Memory.Pool

        // MARK: - Initializers

        /// Creates a pool with the specified capacity.
        ///
        /// All slots start uninitialized. Uses O(1) virgin cursor initialization.
        ///
        /// - Parameter capacity: Number of element slots. Must be > 0.
        /// - Throws: `Pool.Error.invalidCapacity` if capacity is zero.
        /// - Precondition: `MemoryLayout<Element>.stride >= MemoryLayout<Index<Element>>.size`
        @inlinable
        public init(capacity: Index<Element>.Count) throws(Pool.Error) {
            precondition(
                MemoryLayout<Element>.stride >= MemoryLayout<Index<Element>>.size,
                "Element stride must be >= MemoryLayout<Index<Element>>.size for in-band free list"
            )
            do {
                self._pool = try Memory.Pool(
                    slotSize: Memory.Address.Count(UInt(MemoryLayout<Element>.stride)),
                    slotAlignment: try! Memory.Alignment(MemoryLayout<Element>.alignment),
                    capacity: capacity.retag(Memory.Pool.Slot.self)
                )
            } catch {
                switch error {
                case .invalidCapacity:
                    throw .invalidCapacity
                case .exhausted(let capacity):
                    throw .exhausted(capacity: capacity.retag(Element.self))
                case .slotSizeTooSmall, .foreignPointer, .doubleFree:
                    fatalError("Unreachable: \(error)")
                }
            }
        }

        /// Internal initializer wrapping an existing Memory.Pool.
        @usableFromInline
        package init(_wrapping pool: consuming Memory.Pool) {
            self._pool = pool
        }

        // MARK: - Deinit

        deinit {
            _pool.allocatedSlotIndices.forEach { bitIndex in
                unsafe UnsafeMutableRawPointer(_pool.pointer(at: bitIndex.retag(Memory.Pool.Slot.self)))
                    .assumingMemoryBound(to: Element.self)
                    .deinitialize(count: .one)
            }
        }

        // MARK: - Error

        /// Errors that can occur during pool operations.
        public enum Error: Swift.Error, Hashable, Sendable {
            /// No free slots remain.
            case exhausted(capacity: Index<Element>.Count)

            /// The requested capacity is invalid (must be > 0).
            case invalidCapacity

            /// The slot has already been deallocated (double free).
            case doubleFree
        }
    }

    /// Bump-allocated typed storage with bulk reset.
    ///
    /// `Storage<Element>.Arena` is a reference-semantic bump allocator for typed elements.
    /// It provides:
    /// - O(1) allocation (bump pointer)
    /// - No individual deallocation
    /// - Bulk reset via `deinitialize.all()`
    /// - Automatic element deinit in `deinit` (via bitmap iteration)
    /// - Reference semantics for conditional Copyability in buffer compositions
    ///
    /// ## Design Pattern
    ///
    /// Composes `Memory.Arena` for raw byte management. Storage.Arena adds typed
    /// element lifecycle tracking via `Bit.Vector`. Memory.Arena manages the bump
    /// pointer and raw storage; Storage.Arena adds initialization tracking and
    /// typed pointer access.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let arena = try Storage<Node>.Arena(capacity: 64)
    /// if let slot = arena.allocate() {
    ///     arena.pointer(at: slot).initialize(to: node)
    ///     // ... use ...
    /// }
    /// arena.deinitialize.all()  // Deinitializes all elements, resets arena
    /// ```
    public final class Arena {

        // MARK: - Stored Properties

        /// Composed memory arena that manages raw bump allocation.
        @usableFromInline
        package var _arena: Memory.Arena

        /// Tracks which slots are currently initialized for deinit iteration.
        @usableFromInline
        package var _initializationBits: Bit.Vector

        /// Number of currently allocated (initialized) slots.
        @usableFromInline
        package var _allocated: Index<Element>.Count

        /// Total number of element slots.
        @usableFromInline
        package let _capacity: Index<Element>.Count

        /// Element stride in bytes, for pointer arithmetic.
        @usableFromInline
        package let _stride: Int

        // MARK: - Initializers

        /// Creates an arena with the specified element capacity.
        ///
        /// - Parameter capacity: Number of element slots. Must be > 0.
        /// - Precondition: `capacity > .zero`
        @inlinable
        public init(capacity: Index<Element>.Count) {
            precondition(capacity > .zero, "Arena capacity must be > 0")
            let stride = MemoryLayout<Element>.stride
            let totalBytes = Memory.Address.Count(UInt(Int(bitPattern: capacity) * stride))
            self._arena = Memory.Arena(capacity: totalBytes)
            self._initializationBits = Bit.Vector(capacity: capacity.retag(Bit.self))
            self._allocated = .zero
            self._capacity = capacity
            self._stride = stride
        }

        // MARK: - Deinit

        deinit {
            _initializationBits.ones.forEach { bitIndex in
                unsafe pointer(at: bitIndex.retag(Element.self)).deinitialize(count: .one)
            }
        }
    }

    public struct Inline<let capacity: Int>: ~Copyable {
        /// Internal raw storage with automatic layout computation.
        ///
        /// Uses `@_rawLayout(likeArrayOf: Element, count: capacity)` to compute optimal
        /// layout at compile time: `size = stride(Element) × capacity`, `alignment = alignment(Element)`.
        @_rawLayout(likeArrayOf: Element, count: capacity)
        @usableFromInline
        package struct _Raw: ~Copyable {
            @usableFromInline
            init() {}
        }

        @usableFromInline
        package var _storage: _Raw

        /// Per-slot initialization tracking.
        ///
        /// Each bit represents one slot: `true` = initialized, `false` = uninitialized.
        /// Operations automatically update this state.
        ///
        /// Fixed at 4 words (256 bits) to cover all valid capacities without
        /// requiring an additional generic parameter.
        @usableFromInline
        package var _slots: Bit.Vector.Static<4>
        
        // WORKAROUND: Forces correct deinit dispatch for cross-module ~Copyable structs
        // WHY: Swift compiler fails to generate deinit forwarding for ~Copyable structs
        //      containing only value-type properties when Element is from another module.
        //      Adding a reference-type property forces correct codegen.
        // WHEN TO REMOVE: When swiftlang/swift#86652 is fixed
        // TRACKING: https://github.com/swiftlang/swift/issues/86652
        var _deinitWorkaround: AnyObject? = nil

        /// Creates uninitialized inline storage.
        ///
        /// All slots start as uninitialized (all bits cleared).
        ///
        /// - Precondition: `capacity` must be in range `0...256`.
        @inlinable
        public init() {
            precondition(capacity <= 256, "Storage.Inline capacity must be ≤256; use Storage.Heap for larger capacities")
            _storage = _Raw()
            _slots = Bit.Vector.Static<4>()
        }

        deinit {
            _slots.ones.forEach { bitIndex in
                unsafe UnsafeMutablePointer(mutating: pointer(at: bitIndex.retag(Element.self)))
                    .deinitialize(count: .one)
            }
        }
    }
}

// MARK: - Fundamental Slot Access (Heap)

extension Storage.Heap where Element: ~Copyable {
    /// Returns a mutable pointer to the element at the given physical slot.
    ///
    /// This is the primitive address computation for heap storage.
    /// All other slot access methods delegate to this.
    ///
    /// - Parameter slot: The physical slot coordinate.
    /// - Returns: A mutable pointer to the element.
    /// - Warning: The caller must ensure the slot is valid and within capacity.
    @unsafe
    @_lifetime(borrow self)
    @inlinable
    public func pointer(at slot: Index<Element>) -> UnsafeMutablePointer<Element> {
        unsafe withUnsafeMutablePointerToElements {
            unsafe $0 + Index<Element>.Offset(fromZero: slot)
        }
    }

    /// Returns an immutable pointer to the element at the given physical slot.
    ///
    /// - Parameter slot: The physical slot coordinate.
    /// - Returns: An immutable pointer to the element.
    /// - Warning: The caller must ensure the slot is valid and within capacity.
    @unsafe
    @_lifetime(borrow self)
    @inlinable
    @_disfavoredOverload
    public func pointer(at slot: Index<Element>) -> UnsafePointer<Element> {
        unsafe UnsafePointer(pointer(at: slot))
    }
}

// MARK: - Fundamental Slot Access (Inline)

extension Storage.Inline where Element: ~Copyable {
    /// Returns an immutable pointer to the element at the given physical slot.
    ///
    /// This is the primitive address computation for inline storage.
    /// All other slot access methods delegate to this.
    ///
    /// - Parameter slot: The physical slot coordinate.
    /// - Returns: An immutable pointer to the element.
    /// - Precondition: The element at `slot` must be initialized.
    @unsafe
    @_lifetime(borrow self)
    @inlinable
    public func pointer(at slot: Index<Element>) -> UnsafePointer<Element> {
        unsafe withUnsafePointer(to: _storage) { base in
            unsafe UnsafeRawPointer(base)
                .advanced(by: Index<Element>.Offset(fromZero: slot) * .stride)
                .assumingMemoryBound(to: Element.self)
        }
    }
}

// MARK: - Conditional Conformances

// @_rawLayout types require @unchecked Sendable
extension Storage.Inline._Raw: @unchecked Sendable where Element: Sendable {}

// Note: Storage.Inline cannot be conditionally Copyable because _Raw
// (an @_rawLayout type) is always ~Copyable. This is acceptable since Storage.Inline
// manages initialization state and ~Copyable is the correct semantic.

/// `Storage.Inline` is `Sendable` when its elements are `Sendable`.
/// Requires @unchecked because _Raw uses @unchecked Sendable.
extension Storage.Inline: @unchecked Sendable where Element: Sendable {}
