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

public import Bit_Vector_Bounded_Primitives

extension Storage where Element: ~Copyable {
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
}
