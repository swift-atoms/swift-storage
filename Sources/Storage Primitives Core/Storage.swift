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
/// `Storage` provides heap and inline storage building blocks:
/// - ``Storage/Heap``: Heap-allocated storage via ManagedBuffer
/// - ``Storage/Inline``: Fixed-capacity inline storage
///
/// And physical coordinate types for slot-based access:
/// - `Index<Element>`: Physical slot position (typed by element)
/// - `Swift.Range<Index<Element>>`: Contiguous slot range
/// - ``Storage/Initialization``: Which slots are initialized
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
                    .deinitialize(count: 1)
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
            let offset = Index<Element>.Offset(fromZero: slot)
            return unsafe $0 + offset
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
            let raw = unsafe UnsafeRawPointer(base)
            return unsafe raw.advanced(by: Int(bitPattern: slot) * MemoryLayout<Element>.stride)
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
