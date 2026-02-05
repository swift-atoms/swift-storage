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

public import Storage_Primitives_Core

// MARK: - Deinitialize Accessor

extension Storage.Heap where Element: ~Copyable {
    /// Accessor for tracked deinitialize operations.
    ///
    /// Provides `.deinitialize.all()` for safe cleanup.
    ///
    /// ```swift
    /// heap.deinitialize.all()  // Deinitializes all elements, resets to empty
    /// ```
    @inlinable
    public var `deinitialize`: Deinitialize {
        Deinitialize(heap: self)
    }

    /// Nested accessor for tracked deinitialize operations.
    public struct Deinitialize: ~Copyable, ~Escapable {
        @usableFromInline
        let heap: Storage.Heap

        @inlinable
        @_lifetime(borrow heap)
        init(heap: borrowing Storage.Heap) {
            self.heap = copy heap
        }

        /// Deinitializes all elements and resets to empty state.
        ///
        /// This method correctly handles all initialization patterns
        /// (`.empty`, `.linear`, `.one`, `.two`) and resets to `.empty`.
        ///
        /// ```swift
        /// var heap = Storage<Int>.Heap.create(minimumCapacity: 8)
        /// heap.initialize.next(to: 1)
        /// heap.initialize.next(to: 2)
        /// heap.deinitialize.all()  // Elements deinitialized, state is now .empty
        /// ```
        @inlinable
        public func all() {
            heap.deinitialize()
        }
    }
}
