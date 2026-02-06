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

// MARK: - Move Accessor

extension Storage.Heap where Element: ~Copyable {
    /// Accessor for tracked move operations.
    ///
    /// Provides `.move.last()` for linear discipline.
    ///
    /// ```swift
    /// let element = heap.move.last()  // Moves last element, updates state
    /// ```
    @inlinable
    public var move: Move {
        Move(heap: self)
    }

    /// Nested accessor for tracked move operations.
    public struct Move: ~Copyable, ~Escapable {
        @usableFromInline
        let heap: Storage.Heap

        @inlinable
        @_lifetime(borrow heap)
        init(heap: borrowing Storage.Heap) {
            self.heap = copy heap
        }

        /// Moves and returns the last initialized element.
        ///
        /// This method maintains linear discipline: elements are removed
        /// from the end. The initialization state is updated automatically.
        ///
        /// ```swift
        /// var heap = Storage<Int>.Heap.create(minimumCapacity: 8)
        /// heap.initialize.next(to: 1)
        /// heap.initialize.next(to: 2)
        /// let last = heap.move.last()  // Returns 2, count becomes 1
        /// ```
        ///
        /// - Returns: The moved element.
        /// - Precondition: Storage must not be empty.
        /// - Precondition: Storage must be using linear discipline.
        @inlinable
        public func last() -> Element {
            let currentCount = heap.initialization.count
            precondition(currentCount > .zero, "Cannot move.last() from empty storage")
            let newCount = try! currentCount.subtract.exact(.one)
            let slot = Index<Element>(__unchecked: (), Ordinal(newCount.rawValue))
            let element = heap.move(at: slot)
            heap.initialization = newCount == .zero ? .empty : .linear(count: newCount)
            return element
        }
    }
}
