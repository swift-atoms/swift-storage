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

extension Storage.Ring where Element: ~Copyable {
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
        // Use typed arithmetic: (index + 1) % capacity
        (try! index + .one) % capacity
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
        // Add capacity before subtracting to handle wraparound
        (try! index + capacity - .one) % capacity
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
        // Normalize offset to positive range, then add and wrap
        let cap = Int(capacity.count.rawValue)
        let offsetValue = offset.vector.rawValue
        let normalizedOffset = ((offsetValue % cap) + cap) % cap
        let indexValue = Int(index.position.rawValue)
        let result = (indexValue + normalizedOffset) % cap
        return try! Index(result)
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
        // Use typed arithmetic: (head + logicalIndex.position) % capacity
        (try! head + Index.Offset(Int(logicalIndex.position.rawValue))) % capacity
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
        from source: Pointer<Element>.Mutable,
        head: Index<Element>,
        count: Index<Element>.Count,
        capacity: Index<Element>.Count,
        to destination: Pointer<Element>.Mutable
    ) {
        guard count > .zero else { return }
        var srcIndex = head
        (.zero..<count).forEach { dstIndex in
            unsafe (destination.base + dstIndex).initialize(
                to: (source.base + srcIndex).move()
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
        _ elements: Pointer<Element>.Mutable,
        head: Index<Element>,
        count: Index<Element>.Count,
        capacity: Index<Element>.Count
    ) {
        guard count > .zero else { return }
        var index = head
        (.zero..<count).forEach { _ in
            unsafe (elements.base + index).deinitialize(count: 1)
            index = successor(of: index, wrapping: capacity)
        }
    }
}

