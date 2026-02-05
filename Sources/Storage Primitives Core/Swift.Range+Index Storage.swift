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

public import Index_Primitives

// MARK: - Computed Properties

extension Swift.Range where Bound: Ordinal.`Protocol` {
    /// Whether the span contains no slots.
    @inlinable
    public var isEmpty: Bool { lowerBound == upperBound }

    /// The number of positions in the range.
    ///
    /// Returns the cardinal distance from `lowerBound` to `upperBound`.
    /// The result type is `Bound.Count`, preserving phantom types:
    /// - `Range<Ordinal>.count` returns `Cardinal`
    /// - `Range<Index<Element>>.count` returns `Index<Element>.Count`
    @inlinable
    public var count: Bound.Count {
        try! lowerBound.ordinal.distance.forward(to: upperBound.ordinal)
    }
}

// MARK: - Factory Methods

extension Swift.Range {
    /// Creates a span from a start position and count.
    ///
    /// - Parameters:
    ///   - start: The first position in the range.
    ///   - count: The number of positions in the range.
    @inlinable
    public init<T: ~Copyable>(
        start: Bound,
        count: Index_Primitives.Index<T>.Count
    ) where Bound == Index_Primitives.Index<T> {
        unsafe self.init(uncheckedBounds: (lower: start, upper: start + count))
    }
}
