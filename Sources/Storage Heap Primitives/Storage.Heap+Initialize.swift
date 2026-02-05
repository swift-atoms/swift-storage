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

// MARK: - Initialize Accessor

extension Storage.Heap where Element: ~Copyable {
    /// Accessor for tracked initialize operations.
    ///
    /// Provides `.initialize.next(to:)` for linear discipline.
    ///
    /// ```swift
    /// let slot = heap.initialize.next(to: value)  // Initializes next slot, updates state
    /// ```
    @inlinable
    public var initialize: Initialize {
        Initialize(heap: self)
    }

    /// Nested accessor for tracked initialize operations.
    public struct Initialize: ~Copyable, ~Escapable {
        @usableFromInline
        let heap: Storage.Heap

        @inlinable
        @_lifetime(borrow heap)
        init(heap: borrowing Storage.Heap) {
            self.heap = copy heap
        }

        /// Initializes the next available slot with the given element.
        ///
        /// This method maintains linear discipline: elements are stored
        /// contiguously from slot 0. The initialization state is updated
        /// automatically.
        ///
        /// ```swift
        /// var heap = Storage<Int>.Heap.create(minimumCapacity: 8)
        /// heap.initialize.next(to: 1)  // Stored at slot 0
        /// heap.initialize.next(to: 2)  // Stored at slot 1
        /// ```
        ///
        /// - Parameter element: The value to store.
        /// - Returns: The slot where the element was stored.
        /// - Precondition: Storage must have available capacity.
        /// - Precondition: Storage must be using linear discipline (`.empty` or `.linear`).
        @inlinable
        @discardableResult
        public func next(to element: consuming Element) -> Index<Element> {
            let currentCount = heap.initialization.count
            let slot = Index<Element>(currentCount)
            precondition(slot.rawValue < heap.slotCapacity.rawValue, "Storage capacity exceeded")
            heap.initialize(to: element, at: slot)
            let newCount = Index<Element>.Count(currentCount.rawValue + 1)
            heap.initialization = .linear(count: newCount)
            return slot
        }
    }
}
