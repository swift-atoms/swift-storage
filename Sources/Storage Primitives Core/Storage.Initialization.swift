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
    /// Describes which physical slots are initialized.
    ///
    /// Storage deinit iterates these spans to clean up exactly the
    /// initialized slots, regardless of buffer discipline.
    ///
    /// ## Cases
    ///
    /// - `empty`: No slots are initialized
    /// - `one`: A single contiguous range of initialized slots
    /// - `two`: Two disjoint ranges (e.g., wrapped ring buffer)
    ///
    /// ## Invariants
    ///
    /// - `.two` spans are sorted by start: `first.start < second.start`
    /// - `.two` spans are disjoint: `first.end <= second.start`
    ///
    /// ## Example: Ring Buffer Wrapping
    ///
    /// A ring buffer with capacity 8, head at slot 6, and 5 elements:
    /// ```
    /// Slots: [0][1][2][3][4][5][6][7]
    /// Data:   X  X  X  -  -  -  X  X
    ///         └──┴──┘           └──┴── initialized
    /// ```
    /// Initialization: `.two(first: [0,3), second: [6,8))`
    public enum Initialization: Sendable, Equatable {
        /// No slots are initialized.
        case empty

        /// A single contiguous range of initialized slots.
        case one(Swift.Range<Storage.Slot>)

        /// Two disjoint ranges of initialized slots.
        ///
        /// Invariants:
        /// - `first.start < second.start`
        /// - `first.end <= second.start`
        case two(first: Swift.Range<Storage.Slot>, second: Swift.Range<Storage.Slot>)
    }
}

// MARK: - Computed Properties

extension Storage.Initialization {
    /// The total number of initialized slots across all spans.
    @inlinable
    public var count: Storage.Slot.Count {
        switch self {
        case .empty:
            return .zero
        case .one(let span):
            return span.count
        case .two(let first, let second):
            return first.count + second.count
        }
    }

    /// Whether no slots are initialized.
    @inlinable
    public var isEmpty: Bool {
        switch self {
        case .empty:
            return true
        case .one(let span):
            return span.isEmpty
        case .two(let first, let second):
            return first.isEmpty && second.isEmpty
        }
    }
}

// MARK: - Factory Methods

extension Storage.Initialization {
    /// Creates initialization state for a contiguous range starting at zero.
    ///
    /// This is the common case for linear buffers where elements occupy
    /// slots 0..<count.
    ///
    /// - Parameter count: The number of initialized slots.
    @inlinable
    public static func linear(count: Storage.Slot.Count) -> Self {
        guard count > .zero else { return .empty }
        return .one(Swift.Range<Storage.Slot>(start: .zero, count: count))
    }
}
