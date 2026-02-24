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
import Finite_Primitives

/// Namespace for storage primitives.
///
/// `Storage` provides four storage disciplines with different lifecycle contracts:
///
/// | Need | Choose | Lifecycle |
/// |------|--------|-----------|
/// | Automatic cleanup, contiguous elements | ``Storage/Heap`` | **Tracked** — range-based initialization tracking with automatic cleanup in `deinit` |
/// | Stack-allocated, fixed capacity ≤256 | ``Storage/Inline`` | **Auto-tracked** — per-slot bit-vector tracking; consumer responsible for cleanup |
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
            header.initialization.forEach { range in
                guard !range.isEmpty else { return }
                unsafe pointer(at: range.lowerBound).deinitialize(count: range.count)
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
    ///
    /// The consuming buffer type is responsible for iterating set bits to clean
    /// up initialized slots in its own `deinit`. This follows the raw-storage
    /// pattern established by `MaybeUninit` (Rust), `trivial union` (C++26),
    /// and `ManagedBuffer` (Swift stdlib).
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
    /// // Consumer (buffer type) handles cleanup via _slots.ones iteration
    /// ```
    /// Fixed-capacity pool storage with O(1) allocate and deallocate.
    ///
    /// `Storage<Element>.Pool` is a reference-semantic pool allocator for typed elements.
    /// It provides:
    /// - O(1) allocation via virgin cursor + free list
    /// - O(1) deallocation via free list push
    /// - Per-slot reuse (LIFO free list)
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

        /// Returns a mutable pointer to the element at the given slot index.
        ///
        /// Used by buffer-layer consumers for initialization, move, and deinitialization.
        /// Also used internally by deinit. Kept as a named method rather than inlined:
        /// inlining the pointer chain directly into deinit triggers a CopyPropagation
        /// crash on the Property.View.Read temporary created by `_pool.allocation.indices`.
        @unsafe
        @inlinable
        public func pointer(at slot: Index<Element>) -> UnsafeMutablePointer<Element> {
            unsafe _pool.pointer(at: slot.retag(Memory.Pool.Slot.self))
                .assumingMemoryBound(to: Element.self)
        }

        // MARK: - Deinit

        deinit {
            for bitIndex in _pool.allocation.indices {
                unsafe pointer(at: bitIndex.retag(Element.self)).deinitialize(count: .one)
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
        /// - `Index<Element>.Bounded<N>` for precondition-free pointer access
        ///
        /// Element cleanup is the consuming buffer type's responsibility.
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

            /// Creates an empty inline pool with all slots unallocated.
            @inlinable
            public init() {
                precondition(capacity <= 256, "Storage.Pool.Inline capacity must be ≤256")
                _storage = _Raw()
                _slots = Bit.Vector.Static<4>()
                _allocated = .zero
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

        // MARK: - Internal Pointer Helpers

        /// Internal meta pointer for deinit iteration.
        ///
        /// Mirrors `Storage.Arena.meta` from `Storage_Arena_Primitives`
        /// but is available within the core module for deinit use.
        @unsafe
        @inlinable
        package func _meta(at slot: Index<Element>) -> UnsafeMutablePointer<Meta> {
            unsafe _arena.start.assumingMemoryBound(to: Meta.self)
                + Index<Meta>.Offset(fromZero: slot.retag(Meta.self))
        }

        /// Returns a mutable pointer to the element at the given slot index.
        ///
        /// Used by buffer-layer consumers for initialization, move, and deinitialization.
        /// Also used internally by deinit.
        @unsafe
        @inlinable
        public func pointer(at slot: Index<Element>) -> UnsafeMutablePointer<Element> {
            unsafe _arena.start
                .advanced(by: Int(bitPattern: Self._elementRegionOffset(capacity: _slotCapacity)))
                .assumingMemoryBound(to: Element.self)
                + Index<Element>.Offset(fromZero: slot)
        }

        // MARK: - Deinit

        deinit {
            let end = _highWater.map(Ordinal.init)
            var slot: Index<Element> = .zero
            while slot < end {
                if unsafe _meta(at: slot).pointee.isOccupied {
                    unsafe pointer(at: slot).deinitialize(count: .one)
                }
                slot = slot.successor.saturating()
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
        /// - `Index<Element>.Bounded<N>` for precondition-free pointer access
        ///
        /// Element cleanup is the consuming buffer type's responsibility.
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

            /// Creates an empty inline arena with all slots unallocated.
            @inlinable
            public init() {
                precondition(capacity <= 256, "Storage.Arena.Inline capacity must be ≤256")
                _storage = _Raw()
                _slots = Bit.Vector.Static<4>()
                _allocated = .zero
            }
        }
    }

    /// Bitmap-tracked heap storage for slab (sparse) data structures.
    ///
    /// `Storage<Element>.Slab` is a reference-semantic storage class for slab-style
    /// data structures. It provides:
    /// - Heap-allocated element storage via `Storage<Element>.Heap`
    /// - Per-slot occupancy tracking via `Bit.Vector.Bounded`
    /// - Automatic element cleanup in `deinit` (via bitmap iteration)
    /// - Reference semantics for conditional Copyability in buffer compositions
    ///
    /// ## Design Pattern
    ///
    /// Composes `Storage<Element>.Heap` for element storage and `Bit.Vector.Bounded`
    /// for occupancy tracking. The bitmap is the source of truth for which slots
    /// contain initialized elements. `Storage.Heap.initialization` stays `.empty` —
    /// the bitmap drives all cleanup.
    ///
    /// ## Ownership
    ///
    /// Intended to be stored by a `Buffer.Slab` (or `Buffer.Slab.Bounded`) struct.
    /// The struct manages the header (bitmap mirror for mutations); Storage.Slab
    /// manages the backing storage and element deinit.
    public final class Slab {

        // MARK: - Stored Properties

        /// Heap storage for elements.
        @usableFromInline
        package var _heap: Storage<Element>.Heap

        /// Bitmap tracking which slots contain initialized elements.
        /// Synced from Buffer.Slab.Header after mutations.
        @usableFromInline
        package var _bitmap: Bit.Vector.Bounded

        // MARK: - Package Init

        /// Creates slab storage from pre-allocated parts.
        @inlinable
        package init(_heap: Storage<Element>.Heap, bitmap: Bit.Vector.Bounded) {
            self._heap = _heap
            self._bitmap = bitmap
        }

        // MARK: - Deinit

        deinit {
            for bitIndex in _bitmap.ones {
                unsafe _heap.pointer(at: bitIndex.retag(Element.self)).deinitialize(count: .one)
            }
            // Heap's initialization is always .empty for slab usage → Heap deinit is a no-op
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

