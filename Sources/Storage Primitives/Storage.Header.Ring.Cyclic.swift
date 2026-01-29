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

import Cyclic_Index_Primitives

extension Storage.Ring.Header {

    /// Cyclic-indexed header for fixed-capacity ring buffers.
    ///
    /// Uses `Index<Element>.Cyclic<capacity>` for head and tail tracking,
    /// providing automatic wrapping arithmetic. This eliminates manual
    /// capacity parameters and makes invalid indices unrepresentable.
    ///
    /// ## Comparison with `Storage.Ring.Header`
    ///
    /// ```swift
    /// // Storage.Ring.Header (manual wrapping):
    /// header.advanceHead(capacity: capacity)
    ///
    /// // Storage.Ring.Header.Cyclic (automatic wrapping):
    /// header.advanceHead()  // Capacity encoded in type
    /// ```
    ///
    /// ## Usage
    ///
    /// ```swift
    /// var header = Storage<Int>.Ring.Header.Cyclic<8>()
    ///
    /// // Enqueue
    /// storage.initialize(to: 42, at: header.tail)
    /// header.advanceTail()  // tail += .one, wraps at 8
    ///
    /// // Dequeue
    /// let value = storage.move(at: header.head)
    /// header.advanceHead()  // head += .one, wraps at 8
    /// ```
    public struct Cyclic<let capacity: Int>: Sendable {
        /// Physical position of the first element (next dequeue).
        public var head: Index<Element>.Cyclic<capacity>

        /// Physical position for the next element (next enqueue).
        public var tail: Index<Element>.Cyclic<capacity>

        /// Number of valid elements in the buffer.
        public var count: Index<Element>.Count

        /// Creates an empty ring buffer header.
        @inlinable
        public init() {
            self.head = .init(__unchecked: 0)
            self.tail = .init(__unchecked: 0)
            self.count = .zero
        }

        /// Creates a ring buffer header with specified values.
        ///
        /// - Parameters:
        ///   - head: Physical position of front element.
        ///   - tail: Physical position for next insertion.
        ///   - count: Number of elements.
        @inlinable
        public init(
            head: Index<Element>.Cyclic<capacity>,
            tail: Index<Element>.Cyclic<capacity>,
            count: Index<Element>.Count
        ) {
            self.head = head
            self.tail = tail
            self.count = count
        }

        /// Whether the buffer is empty.
        @inlinable
        public var isEmpty: Bool {
            count == .zero
        }

        /// Whether the buffer is full.
        @inlinable
        public var isFull: Bool {
            Int(bitPattern: count) == capacity
        }

        /// Advances head after dequeue.
        ///
        /// The cyclic index wraps automatically at capacity.
        ///
        /// - Precondition: count > 0
        @inlinable
        public mutating func advanceHead() {
            head += .one
            count = count.subtract.saturating(.one)
        }

        /// Advances tail after enqueue.
        ///
        /// The cyclic index wraps automatically at capacity.
        ///
        /// - Precondition: count < capacity
        @inlinable
        public mutating func advanceTail() {
            tail += .one
            count = count + .one
        }

        /// Retreats head before prepend (for deque operations).
        ///
        /// The cyclic index wraps automatically at capacity.
        ///
        /// - Precondition: count < capacity
        @inlinable
        public mutating func retreatHead() {
            head -= .one
            count = count + .one
        }

        /// Retreats tail before pop-back (for deque operations).
        ///
        /// The cyclic index wraps automatically at capacity.
        ///
        /// - Precondition: count > 0
        @inlinable
        public mutating func retreatTail() {
            tail -= .one
            count = count.subtract.saturating(.one)
        }

        /// Resets the header to empty state.
        @inlinable
        public mutating func reset() {
            head = .init(__unchecked: 0)
            tail = .init(__unchecked: 0)
            count = .zero
        }

        /// Converts the head position to a linear index.
        @inlinable
        public var headIndex: Index<Element> {
            Index<Element>(Ordinal(head.rawValue.position.rawValue))
        }

        /// Converts the tail position to a linear index.
        @inlinable
        public var tailIndex: Index<Element> {
            Index<Element>(Ordinal(tail.rawValue.position.rawValue))
        }
    }
}
