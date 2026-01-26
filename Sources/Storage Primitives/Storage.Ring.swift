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

extension Storage {
    /// Circular buffer storage operations.
    ///
    /// Operations for ring buffer storage where elements wrap around the capacity
    /// boundary. Used by Queue and Deque.
    ///
    /// ## Ring Buffer Semantics
    ///
    /// Ring buffers maintain a circular view over contiguous storage. Elements are
    /// logically ordered from head to tail, but physically wrap at capacity:
    ///
    /// ```
    /// Physical:  [ 2 | 3 | 4 | 0 | 1 ]
    ///                        ^head
    /// Logical:   [ 0 | 1 | 2 | 3 | 4 ]
    /// ```
    ///
    /// All operations maintain the invariant that results are in `0..<capacity`.
    public enum Ring {}
}

extension Storage.Ring {
    /// Advances an index by one position, wrapping at capacity.
    ///
    /// - Parameters:
    ///   - index: The current index.
    ///   - capacity: The buffer capacity (must be positive).
    /// - Returns: The successor index wrapped to `0..<capacity`.
    /// - Complexity: O(1)
    @inlinable
    public static func successor(
        of index: Index<Element>,
        wrapping capacity: Index<Element>.Count
    ) -> Index<Element> {
        Index(__unchecked: (), position: (index.position.rawValue + 1) % capacity.rawValue)
    }

    /// Retreats an index by one position, wrapping at capacity.
    ///
    /// - Parameters:
    ///   - index: The current index.
    ///   - capacity: The buffer capacity (must be positive).
    /// - Returns: The predecessor index wrapped to `0..<capacity`.
    /// - Complexity: O(1)
    @inlinable
    public static func predecessor(
        of index: Index<Element>,
        wrapping capacity: Index<Element>.Count
    ) -> Index<Element> {
        Index(__unchecked: (), position: (index.position.rawValue - 1 + capacity.rawValue) % capacity.rawValue)
    }

    /// Advances an index by an offset, wrapping at capacity.
    ///
    /// - Parameters:
    ///   - index: The starting index.
    ///   - offset: The offset to advance by (can be negative).
    ///   - capacity: The buffer capacity (must be positive).
    /// - Returns: The resulting index wrapped to `0..<capacity`.
    /// - Complexity: O(1)
    @inlinable
    public static func advanced(
        _ index: Index<Element>,
        by offset: Index<Element>.Offset,
        wrapping capacity: Index<Element>.Count
    ) -> Index<Element> {
        let cap = capacity.rawValue
        let raw = (index.position.rawValue + offset.rawValue % cap + cap) % cap
        return Index(__unchecked: (), position: raw)
    }

    /// Calculates the physical index from a logical index in a ring buffer.
    ///
    /// Converts a logical index (0 = front of queue) to a physical storage position
    /// given the current head position.
    ///
    /// - Parameters:
    ///   - logicalIndex: The logical index (0..<count).
    ///   - head: The physical position of the first element.
    ///   - capacity: The buffer capacity.
    /// - Returns: The physical storage index.
    /// - Complexity: O(1)
    @inlinable
    public static func physicalIndex(
        forLogical logicalIndex: Index<Element>,
        head: Index<Element>,
        capacity: Index<Element>.Count
    ) -> Index<Element> {
        Index(__unchecked: (), position: (head.position.rawValue + logicalIndex.position.rawValue) % capacity.rawValue)
    }
}
