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

extension Swift.Range<Index<Storage>> {
    /// Whether the span contains no slots.
    @inlinable
    public var isEmpty: Bool { lowerBound == upperBound }

    /// The number of slots in the span.
    @inlinable
    public var count: Storage.Slot.Count {
        try! lowerBound.distance.forward(to: upperBound)
    }
}

// MARK: - Factory Methods

extension Swift.Range<Storage.Slot> {
    /// An empty span starting and ending at slot zero.
    @inlinable
    public static var empty: Self {
        .init(start: .zero, count: .zero)
    }

    /// Creates a span from a start slot and count.
    ///
    /// - Parameters:
    ///   - start: The first slot in the range.
    ///   - count: The number of slots in the range.
    @inlinable
    public init(
        start: Storage.Slot,
        count: Storage.Slot.Count
    ) {
        unsafe self.init(uncheckedBounds: (lower: start, upper: start + count))
    }
}
