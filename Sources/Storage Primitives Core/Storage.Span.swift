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

extension Storage {
    /// A contiguous range of initialized physical slots [start, end).
    ///
    /// Represents a half-open interval of slot positions. Used by
    /// ``Storage/Initialization`` to describe which slots contain
    /// initialized elements.
    public struct Span: Sendable, Equatable {
        /// The first slot in the range (inclusive).
        public let start: Slot

        /// The slot after the last slot in the range (exclusive).
        public let end: Slot

        /// Creates a span from start (inclusive) to end (exclusive).
        ///
        /// - Parameters:
        ///   - start: The first slot in the range.
        ///   - end: The slot after the last slot in the range.
        /// - Precondition: `start <= end`
        @inlinable
        public init(start: Slot, end: Slot) {
            precondition(start <= end, "Span start must not exceed end")
            self.start = start
            self.end = end
        }
    }
}

// MARK: - Computed Properties

extension Storage.Span {
    /// Whether the span contains no slots.
    @inlinable
    public var isEmpty: Bool { start == end }

    /// The number of slots in the span.
    @inlinable
    public var count: Storage.Slot.Count {
        try! start.distance.forward(to: end)
    }
}

// MARK: - Factory Methods

extension Storage.Span {
    /// An empty span starting and ending at slot zero.
    @inlinable
    public static var empty: Self {
        Self(start: .zero, end: .zero)
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
        self.init(start: start, end: start + count)
    }
}
