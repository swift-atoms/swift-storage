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
public import Finite_Primitives

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

        // MARK: - Internal Pointer

        /// Internal pointer for deinit iteration.
        ///
        /// Mirrors `Storage.Pool.pointer(at:)` from `Storage_Pool_Primitives`
        /// but is available within the core module for deinit use.
        @unsafe
        @inlinable
        package func _pointer(at slot: Index<Element>) -> UnsafeMutablePointer<Element> {
            unsafe _pool.pointer(at: slot.retag(Memory.Pool.Slot.self))
                .assumingMemoryBound(to: Element.self)
        }

        // MARK: - Deinit

        deinit {
            _pool.allocation.indices.forEach { bitIndex in
                unsafe _pointer(at: bitIndex.retag(Element.self)).deinitialize(count: .one)
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

        // MARK: - Inline Pool

        /// Static-capacity inline pool with bitmap-scanned per-slot reuse.
        ///
        /// `Storage<Element>.Pool.Inline<N>` is a stack-backed pool allocator for typed elements.
        /// It provides:
        /// - O(capacity) allocation via bitmap scanning (no in-band free list)
        /// - O(1) deallocation via bit flip
        /// - Per-slot reuse (bitmap-tracked)
        /// - Automatic element deinit in `deinit` (via bitmap iteration)
        /// - `Index<Element>.Bounded<N>` for precondition-free pointer access
        ///
        /// ## Design
        ///
        /// Uses bitmap scanning instead of in-band free list links:
        /// - Single source of truth (no inconsistent secondary structure)
        /// - No `Element` stride constraint (works with `UInt8`)
        /// - Acceptable performance for N ≤ 256 (at most 4 words to scan)
        ///
        /// ## Invariants
        ///
        /// - `capacity` is a compile-time constant in range `0...256`
        /// - `_slots` bit `i` is set iff slot `i` contains an allocated element
        /// - `_allocated == _slots.popcount` (cached for O(1) access)
        ///
        /// ## Usage
        ///
        /// ```swift
        /// var pool = Storage<Node>.Pool.Inline<16>()
        /// let slot = try pool.allocate()
        /// pool.pointer(at: slot).initialize(to: node)
        /// // ... use ...
        /// _ = pool.pointer(at: slot).move()
        /// try pool.deallocate(at: slot)
        /// ```
        public struct Inline<let capacity: Int>: ~Copyable {
            @_rawLayout(likeArrayOf: Element, count: capacity)
            @usableFromInline
            package struct _Raw: ~Copyable {
                @usableFromInline init() {}
            }

            @usableFromInline package var _storage: _Raw
            @usableFromInline package var _slots: Bit.Vector.Static<4>
            @usableFromInline package var _allocated: Index<Element>.Count
            // WORKAROUND: Forces correct deinit dispatch for cross-module ~Copyable structs
            // WHEN TO REMOVE: When swiftlang/swift#86652 is fixed
            var _deinitWorkaround: AnyObject? = nil

            /// Creates an empty inline pool with all slots unallocated.
            @inlinable
            public init() {
                precondition(capacity <= 256, "Storage.Pool.Inline capacity must be ≤256")
                _storage = _Raw()
                _slots = Bit.Vector.Static<4>()
                _allocated = .zero
            }

            deinit {
                _slots.ones.forEach { bitIndex in
                    unsafe _pointer(at: bitIndex.retag(Element.self)).deinitialize(count: .one)
                }
            }
        }
    }

    /// Slot-based typed storage with generation tokens and SoA layout.
    ///
    /// `Storage<Element>.Arena` is a reference-semantic storage class for arena-style
    /// data structures. It provides:
    /// - SoA layout: per-slot metadata (generation tokens) + element array
    /// - Automatic element cleanup in `deinit` (via generation-token iteration)
    /// - Reference semantics for conditional Copyability in buffer compositions
    ///
    /// ## Design Pattern
    ///
    /// Composes `Memory.Arena` for raw byte management. Storage.Arena lays out
    /// a meta array and an element array contiguously within Memory.Arena's raw
    /// allocation. Memory.Arena manages allocation lifecycle (RAII); Storage.Arena
    /// adds typed layout, element lifecycle, and reference semantics.
    ///
    /// ## Layout
    ///
    /// ```
    /// baseAddress
    /// │
    /// ▼
    /// ┌─────────────────────────────────────────────────────────────────────┐
    /// │ Meta₀ │ Meta₁ │ ... │ Meta_{n-1} │ [align pad] │ E₀ │ ... │ E_{n-1} │
    /// └─────────────────────────────────────────────────────────────────────┘
    /// ```
    ///
    /// ## Ownership
    ///
    /// Intended to be stored by a `Buffer.Arena` (or `Buffer.Arena.Bounded`) struct.
    /// The struct manages the header (occupied count, free-list head); Storage.Arena
    /// manages the backing storage and element deinit.
    public final class Arena {

        // MARK: - Stored Properties

        /// Composed memory arena — owns the raw allocation lifecycle.
        @usableFromInline
        package var _arena: Memory.Arena

        /// Total number of element slots.
        @usableFromInline
        package let _slotCapacity: Index<Element>.Count

        /// Highest slot index ever allocated. Used by deinit to bound iteration.
        /// Must be synced (write-through) from the owning Buffer.Arena's header.
        @usableFromInline
        package var _highWater: Index<Element>.Count

        // MARK: - Package Init

        /// Creates a storage arena from pre-allocated parts.
        @inlinable
        package init(
            _arena: consuming Memory.Arena,
            slotCapacity: Index<Element>.Count,
            highWater: Index<Element>.Count
        ) {
            self._arena = _arena
            self._slotCapacity = slotCapacity
            self._highWater = highWater
        }

        // MARK: - Meta

        /// Per-slot metadata: generation token + free-list link.
        ///
        /// Token parity is the sole occupancy oracle:
        /// - Even token (including 0) → free or virgin
        /// - Odd token → occupied
        ///
        /// `link` chains freed slots into a LIFO free-list.
        /// `UInt32.max` = end of list (no next).
        ///
        /// 8 bytes per slot.
        @frozen
        public struct Meta: BitwiseCopyable {
            /// Parity-tagged generation counter. Even = free, odd = occupied.
            public var token: UInt32

            /// Free-list link: index of the next free slot, or `UInt32.max` if none.
            public var link: UInt32

            /// Creates metadata with the given token and free-list link.
            @inlinable
            public init(token: UInt32, link: UInt32) {
                self.token = token
                self.link = link
            }

            /// Whether this slot is currently occupied (odd token = occupied).
            @inlinable
            public var isOccupied: Bool { token & 1 == 1 }

            /// Virgin slot metadata: token 0 (free, never allocated), no next.
            @inlinable
            public static var virgin: Meta { Meta(token: 0, link: .max) }
        }

        // MARK: - Layout

        /// Byte offset from `baseAddress` to the element region.
        @inlinable
        public static func _elementRegionOffset(
            capacity: Index<Element>.Count
        ) -> Memory.Address.Count {
            let metaBytes: Memory.Address.Count = capacity.retag(Meta.self) * .stride
            let elementAlignment = try! Memory.Alignment(max(MemoryLayout<Element>.alignment, 1))
            return elementAlignment.align.up(metaBytes)
        }

        /// Total bytes required for the SoA layout.
        @inlinable
        public static func _totalBytes(
            capacity: Index<Element>.Count
        ) -> Memory.Address.Count {
            _elementRegionOffset(capacity: capacity) + capacity * .stride
        }

        // MARK: - Pointer Access

        /// Pointer to the meta array base.
        @unsafe
        @inlinable
        public var meta: UnsafeMutablePointer<Meta> {
            unsafe _arena.start.assumingMemoryBound(to: Meta.self)
        }

        /// Pointer to the element at the given slot index.
        @unsafe
        @inlinable
        public func pointer(
            at slot: Index<Element>
        ) -> UnsafeMutablePointer<Element> {
            let offset = Int(bitPattern: Self._elementRegionOffset(capacity: _slotCapacity))
            return unsafe _arena.start
                .advanced(by: offset + Int(bitPattern: slot) * MemoryLayout<Element>.stride)
                .assumingMemoryBound(to: Element.self)
        }

        // MARK: - Deinit

        deinit {
            // WORKAROUND: Uses `for i in` instead of `.forEach` closure
            // WHY: Closures capturing ~Copyable fields of `self` inside deinit trigger
            //      CopiedLoadBorrowEliminationVisitor segfault (swift-frontend signal 11)
            // WHEN TO REMOVE: When MoveOnlyChecker deinit closure crash is fixed
            let hw = Int(bitPattern: _highWater)
            let meta = unsafe _arena.start.assumingMemoryBound(to: Meta.self)
            let offset = Int(bitPattern: Self._elementRegionOffset(capacity: _slotCapacity))
            let elemBase = unsafe _arena.start.advanced(by: offset)
            let stride = MemoryLayout<Element>.stride
            for i in 0..<hw {
                if meta[i].isOccupied {
                    unsafe elemBase
                        .advanced(by: i * stride)
                        .assumingMemoryBound(to: Element.self)
                        .deinitialize(count: .one)
                }
            }
            // Memory.Arena deinit fires automatically → frees raw storage
        }

        // MARK: - Inline Arena

        /// Static-capacity inline arena with bump allocation and bulk reset.
        ///
        /// `Storage<Element>.Arena.Inline<N>` is a stack-backed bump allocator for typed elements.
        /// It provides:
        /// - O(1) allocation (sequential bump)
        /// - No individual deallocation
        /// - Bulk reset via `deinitialize.all()`
        /// - Automatic element deinit in `deinit` (via bitmap iteration)
        /// - `Index<Element>.Bounded<N>` for precondition-free pointer access
        ///
        /// ## Invariants
        ///
        /// - `capacity` is a compile-time constant in range `0...256`
        /// - `_slots` bit `i` is set iff slot `i` contains an allocated element
        /// - `_allocated == _slots.popcount` (cached for O(1) access)
        /// - Allocation is sequential: slots 0..<_allocated are allocated
        ///
        /// ## Usage
        ///
        /// ```swift
        /// var arena = Storage<Node>.Arena.Inline<16>()
        /// if let slot = arena.allocate() {
        ///     arena.pointer(at: slot).initialize(to: node)
        ///     // ... use ...
        /// }
        /// arena.deinitialize.all()
        /// ```
        public struct Inline<let capacity: Int>: ~Copyable {
            @_rawLayout(likeArrayOf: Element, count: capacity)
            @usableFromInline
            package struct _Raw: ~Copyable {
                @usableFromInline init() {}
            }

            @usableFromInline package var _storage: _Raw
            @usableFromInline package var _slots: Bit.Vector.Static<4>
            @usableFromInline package var _allocated: Index<Element>.Count
            // WORKAROUND: Forces correct deinit dispatch for cross-module ~Copyable structs
            // WHEN TO REMOVE: When swiftlang/swift#86652 is fixed
            var _deinitWorkaround: AnyObject? = nil

            /// Creates an empty inline arena with all slots unallocated.
            @inlinable
            public init() {
                precondition(capacity <= 256, "Storage.Arena.Inline capacity must be ≤256")
                _storage = _Raw()
                _slots = Bit.Vector.Static<4>()
                _allocated = .zero
            }

            deinit {
                _slots.ones.forEach { bitIndex in
                    unsafe _pointer(at: bitIndex.retag(Element.self)).deinitialize(count: .one)
                }
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
    /// Returns a mutable pointer to the element at the given bounded physical slot.
    ///
    /// Precondition-free — the bounded index guarantees validity.
    ///
    /// - Parameter slot: A bounded physical slot coordinate.
    /// - Returns: A mutable pointer to the element.
    @unsafe
    @_lifetime(borrow self)
    @inlinable
    public func pointer(at slot: Index<Element>.Bounded<capacity>) -> UnsafeMutablePointer<Element> {
        unsafe UnsafeMutablePointer(mutating: pointer(at: Index<Element>(slot)))
    }

    /// Returns an immutable pointer to the element at the given bounded physical slot.
    ///
    /// Precondition-free — the bounded index guarantees validity.
    ///
    /// - Parameter slot: A bounded physical slot coordinate.
    /// - Returns: An immutable pointer to the element.
    @unsafe
    @_lifetime(borrow self)
    @inlinable
    @_disfavoredOverload
    public func pointer(at slot: Index<Element>.Bounded<capacity>) -> UnsafePointer<Element> {
        unsafe pointer(at: Index<Element>(slot))
    }

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
    package func pointer(at slot: Index<Element>) -> UnsafePointer<Element> {
        unsafe withUnsafePointer(to: _storage) { base in
            unsafe UnsafeRawPointer(base)
                .advanced(by: Index<Element>.Offset(fromZero: slot) * .stride)
                .assumingMemoryBound(to: Element.self)
        }
    }
}

// MARK: - Fundamental Slot Access (Pool.Inline)

extension Storage.Pool.Inline where Element: ~Copyable {
    /// Returns a mutable pointer to the element at the given bounded slot.
    ///
    /// Precondition-free — the bounded index guarantees validity.
    ///
    /// - Parameter slot: A bounded slot index returned by `allocate()`.
    /// - Returns: Mutable pointer to the element's memory.
    @unsafe
    @_lifetime(borrow self)
    @inlinable
    public func pointer(at slot: Index<Element>.Bounded<capacity>) -> UnsafeMutablePointer<Element> {
        unsafe _pointer(at: Index<Element>(slot))
    }

    /// Returns an immutable pointer to the element at the given bounded slot.
    ///
    /// Precondition-free — the bounded index guarantees validity.
    ///
    /// - Parameter slot: A bounded slot index returned by `allocate()`.
    /// - Returns: Immutable pointer to the element's memory.
    @unsafe
    @_lifetime(borrow self)
    @inlinable
    @_disfavoredOverload
    public func pointer(at slot: Index<Element>.Bounded<capacity>) -> UnsafePointer<Element> {
        unsafe UnsafePointer(_pointer(at: Index<Element>(slot)))
    }

    /// Internal unbounded pointer for deinit iteration.
    @unsafe
    @_lifetime(borrow self)
    @inlinable
    package func _pointer(at slot: Index<Element>) -> UnsafeMutablePointer<Element> {
        unsafe withUnsafePointer(to: _storage) { base in
            unsafe UnsafeMutablePointer(mutating:
                UnsafeRawPointer(base)
                    .advanced(by: Index<Element>.Offset(fromZero: slot) * .stride)
                    .assumingMemoryBound(to: Element.self)
            )
        }
    }
}

// MARK: - Fundamental Slot Access (Arena.Inline)

extension Storage.Arena.Inline where Element: ~Copyable {
    /// Returns a mutable pointer to the element at the given bounded slot.
    ///
    /// Precondition-free — the bounded index guarantees validity.
    ///
    /// - Parameter slot: A bounded slot index returned by `allocate()`.
    /// - Returns: Mutable pointer to the element's memory.
    @unsafe
    @_lifetime(borrow self)
    @inlinable
    public func pointer(at slot: Index<Element>.Bounded<capacity>) -> UnsafeMutablePointer<Element> {
        unsafe _pointer(at: Index<Element>(slot))
    }

    /// Returns an immutable pointer to the element at the given bounded slot.
    ///
    /// Precondition-free — the bounded index guarantees validity.
    ///
    /// - Parameter slot: A bounded slot index returned by `allocate()`.
    /// - Returns: Immutable pointer to the element's memory.
    @unsafe
    @_lifetime(borrow self)
    @inlinable
    @_disfavoredOverload
    public func pointer(at slot: Index<Element>.Bounded<capacity>) -> UnsafePointer<Element> {
        unsafe UnsafePointer(_pointer(at: Index<Element>(slot)))
    }

    /// Internal unbounded pointer for deinit iteration.
    @unsafe
    @_lifetime(borrow self)
    @inlinable
    package func _pointer(at slot: Index<Element>) -> UnsafeMutablePointer<Element> {
        unsafe withUnsafePointer(to: _storage) { base in
            unsafe UnsafeMutablePointer(mutating:
                UnsafeRawPointer(base)
                    .advanced(by: Index<Element>.Offset(fromZero: slot) * .stride)
                    .assumingMemoryBound(to: Element.self)
            )
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

// Pool.Inline
extension Storage.Pool.Inline._Raw: @unchecked Sendable where Element: Sendable {}
extension Storage.Pool.Inline: @unchecked Sendable where Element: Sendable {}

// Arena.Inline
extension Storage.Arena.Inline._Raw: @unchecked Sendable where Element: Sendable {}
extension Storage.Arena.Inline: @unchecked Sendable where Element: Sendable {}
