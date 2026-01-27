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

extension Storage.Ring {
    /// Header for ring buffer storage.
    ///
    /// Tracks head (dequeue position), tail (enqueue position), and count.
    /// Used by Queue and Deque where elements wrap around the capacity boundary.
    ///
    /// ## Invariants
    ///
    /// - `count` reflects number of valid elements
    /// - Elements occupy physical positions from `head` to `(head + count - 1) % capacity`
    /// - `tail == (head + count) % capacity` when buffer is not full
    /// - `head == tail` when buffer is empty OR full (disambiguated by count)
    ///
    /// ## Physical Layout Example
    ///
    /// ```
    /// Capacity: 5, Count: 3, Head: 3, Tail: 1
    /// Physical:  [ X | _ | _ | A | B ]
    ///              ^tail      ^head
    /// Logical:   [ A | B | X ]
    /// ```
    public struct Header: ~Copyable, Sendable {
        /// Physical position of next element to dequeue.
        public var head: Index<Element>

        /// Physical position where next element will be enqueued.
        public var tail: Index<Element>

        /// Number of valid elements in the buffer.
        public var count: Index<Element>.Count

        /// Creates an empty ring buffer header.
        @inlinable
        public init() {
            self.head = .zero
            self.tail = .zero
            self.count = .zero
        }

        /// Creates a ring buffer header with specified values.
        ///
        /// - Parameters:
        ///   - head: Physical position of front element.
        ///   - tail: Physical position for next insertion.
        ///   - count: Number of elements.
        @inlinable
        public init(head: Index<Element>, tail: Index<Element>, count: Index<Element>.Count) {
            self.head = head
            self.tail = tail
            self.count = count
        }

        /// Whether the buffer is empty.
        @inlinable
        public var isEmpty: Bool {
            count == .zero
        }

        /// Advances head after dequeue, wrapping at capacity.
        ///
        /// - Parameter capacity: The buffer capacity.
        /// - Precondition: count > 0
        @inlinable
        public mutating func advanceHead(capacity: Index<Element>.Count) {
            head = Storage<Element>.Ring.successor(of: head, wrapping: capacity)
            count = count.subtract.saturating(.one)
        }

        /// Advances tail after enqueue, wrapping at capacity.
        ///
        /// - Parameter capacity: The buffer capacity.
        /// - Precondition: count < capacity
        @inlinable
        public mutating func advanceTail(capacity: Index<Element>.Count) {
            tail = Storage<Element>.Ring.successor(of: tail, wrapping: capacity)
            count = count + .one
        }

        /// Retreats head before enqueue at front, wrapping at capacity.
        ///
        /// Used by Deque for prepend operations.
        ///
        /// - Parameter capacity: The buffer capacity.
        /// - Precondition: count < capacity
        @inlinable
        public mutating func retreatHead(capacity: Index<Element>.Count) {
            head = Storage<Element>.Ring.predecessor(of: head, wrapping: capacity)
            count = count + .one
        }

        /// Retreats tail before dequeue from back, wrapping at capacity.
        ///
        /// Used by Deque for pop-back operations.
        ///
        /// - Parameter capacity: The buffer capacity.
        /// - Precondition: count > 0
        @inlinable
        public mutating func retreatTail(capacity: Index<Element>.Count) {
            tail = Storage<Element>.Ring.predecessor(of: tail, wrapping: capacity)
            count = count.subtract.saturating(.one)
        }
    }
}
