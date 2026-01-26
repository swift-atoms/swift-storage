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

    // MARK: - Bulk Operations

    /// Moves elements from a ring buffer to linear storage.
    ///
    /// Elements are read from `head` position with wrapping at `capacity`,
    /// and written linearly starting at destination index 0. Source elements
    /// are deinitialized after moving.
    ///
    /// - Parameters:
    ///   - source: Mutable pointer to source ring buffer elements.
    ///   - head: Physical index of first element in ring.
    ///   - count: Number of elements to move.
    ///   - capacity: Source buffer capacity (for wrapping).
    ///   - destination: Pointer to destination (linear, starting at 0).
    @inlinable
    public static func linearize(
        from source: UnsafeMutablePointer<Element>,
        head: Index<Element>,
        count: Index<Element>.Count,
        capacity: Index<Element>.Count,
        to destination: UnsafeMutablePointer<Element>
    ) {
        guard count > .zero else { return }
        var srcIndex = head
        for dstIndex in 0..<count.rawValue {
            unsafe (destination + dstIndex).initialize(
                to: (source + srcIndex.position.rawValue).move()
            )
            srcIndex = successor(of: srcIndex, wrapping: capacity)
        }
    }

    /// Deinitializes elements in a ring buffer.
    ///
    /// Elements are visited from `head` position with wrapping at capacity.
    ///
    /// - Parameters:
    ///   - elements: Pointer to element storage.
    ///   - head: Physical index of first element.
    ///   - count: Number of elements to deinitialize.
    ///   - capacity: Buffer capacity (for wrapping).
    @inlinable
    public static func deinitialize(
        _ elements: UnsafeMutablePointer<Element>,
        head: Index<Element>,
        count: Index<Element>.Count,
        capacity: Index<Element>.Count
    ) {
        guard count > .zero else { return }
        var index = head
        for _ in 0..<count.rawValue {
            unsafe (elements + index.position.rawValue).deinitialize(count: 1)
            index = successor(of: index, wrapping: capacity)
        }
    }
}

// MARK: - Copyable Ring Operations

extension Storage.Ring where Element: Copyable {
    /// Copies elements from a ring buffer to linear storage.
    ///
    /// Non-destructive variant. Source pointer immutability distinguishes
    /// this overload from the move variant.
    ///
    /// - Parameters:
    ///   - source: Immutable pointer to source ring buffer elements.
    ///   - head: Physical index of first element in ring.
    ///   - count: Number of elements to copy.
    ///   - capacity: Source buffer capacity (for wrapping).
    ///   - destination: Pointer to destination (linear, starting at 0).
    @inlinable
    public static func linearize(
        from source: UnsafePointer<Element>,
        head: Index<Element>,
        count: Index<Element>.Count,
        capacity: Index<Element>.Count,
        to destination: UnsafeMutablePointer<Element>
    ) {
        guard count > .zero else { return }
        var srcIndex = head
        for dstIndex in 0..<count.rawValue {
            unsafe (destination + dstIndex).initialize(
                to: (source + srcIndex.position.rawValue).pointee
            )
            srcIndex = successor(of: srcIndex, wrapping: capacity)
        }
    }
}
