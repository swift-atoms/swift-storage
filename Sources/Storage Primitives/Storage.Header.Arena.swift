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

extension Storage.Header {
    /// Header for arena-based storage with free-list.
    ///
    /// Used by List.Linked for index-based node allocation. Supports O(1)
    /// allocation and deallocation via a free list of reusable slots.
    ///
    /// ## Free List Management
    ///
    /// Freed slots are linked via indices stored in the deallocated memory.
    /// `freeHead` points to the first free slot, which in turn points to the
    /// next free slot, forming a linked list. `sentinel` indicates end of list.
    ///
    /// ## Memory Layout
    ///
    /// ```
    /// Slots:    [ Node | FREE | Node | FREE | Node ]
    ///                    ↓             ↓
    /// freeHead: 1 → slot[1].next = 3 → slot[3].next = sentinel
    /// ```
    public struct Arena: ~Copyable, Sendable {
        /// Index of first element in logical order.
        public var head: Index<Element>

        /// Index of last element in logical order.
        public var tail: Index<Element>

        /// Index of first free slot (for reuse).
        public var freeHead: Index<Element>

        /// Number of valid elements.
        public var count: Index<Element>.Count

        /// Total slots allocated.
        public var capacity: Index<Element>.Count

        /// Sentinel value indicating no element or end of free list.
        ///
        /// Uses UInt.max which is invalid for normal indices.
        @inlinable
        public static var sentinel: Index<Element> {
            Index(__unchecked: (), Ordinal(UInt.max))
        }

        /// Creates an empty arena header.
        @inlinable
        public init() {
            self.head = Self.sentinel
            self.tail = Self.sentinel
            self.freeHead = Self.sentinel
            self.count = .zero
            self.capacity = .zero
        }

        /// Creates an arena header with specified capacity.
        ///
        /// - Parameter capacity: Initial storage capacity.
        @inlinable
        public init(capacity: Index<Element>.Count) {
            self.head = Self.sentinel
            self.tail = Self.sentinel
            self.freeHead = Self.sentinel
            self.count = .zero
            self.capacity = capacity
        }

        /// Whether the arena is empty.
        @inlinable
        public var isEmpty: Bool {
            count == .zero
        }

        /// Whether the free list has available slots.
        @inlinable
        public var hasFreeSlots: Bool {
            freeHead != Self.sentinel
        }

        /// Checks if an index is the sentinel value.
        ///
        /// - Parameter index: The index to check.
        /// - Returns: `true` if the index is the sentinel.
        @inlinable
        public static func isSentinel(_ index: Index<Element>) -> Bool {
            index == sentinel
        }
    }
}
