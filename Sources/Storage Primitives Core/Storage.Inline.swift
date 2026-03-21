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

extension Storage where Element: ~Copyable {
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
        ///
        /// LAYERING: `_slots` belongs in Storage, not the buffer layer.
        /// Tracking which physical slots are initialized is a storage concern —
        /// buffer types manage logical state (head/count/capacity).
        ///
        /// COMPILER BUG (swiftlang/swift#86652): This second stored field
        /// alongside `_storage` triggers the 2-field rule, preventing
        /// Storage.Inline from having a deinit under -O.
        ///
        /// VIABLE FIX: Encode the bitmap WITHIN the @_rawLayout region using
        /// `@_rawLayout(like: CombinedLayout)` where CombinedLayout contains
        /// both element storage and bitmap. This reduces Storage.Inline to
        /// 1 stored field, satisfying the 2-field rule. `_slots` becomes a
        /// computed property backed by pointer access into the raw region.
        /// See: rawlayout-release-crash-investigation.md (in buffer-primitives)
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
