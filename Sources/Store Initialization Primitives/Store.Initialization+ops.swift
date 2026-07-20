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
public import Store_Primitive

// MARK: - Computed Properties

extension Store.Initialization where Element: ~Copyable & ~Escapable {
    /// The total number of initialized slots across all spans.
    @inlinable
    public var count: Index_Primitives.Index<Element>.Count {
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

// MARK: - Prefix Shape

extension Store.Initialization where Element: ~Copyable & ~Escapable {
    /// Whether this ledger describes a single contiguous run starting at slot zero
    /// (or is empty).
    ///
    /// `Storage.Contiguous`'s span family (`span`, `mutableSpan`, `outputSpan`,
    /// `withOutputSpan`, `mutableSpan(count:)`, `copy()`) and the `Store.`Protocol``
    /// seam's self-maintained `initialize(at:to:)` / `move(at:)` arithmetic both
    /// assume this shape — they treat the live region as exactly `[0, count)`. A
    /// `.two` (wrapped) shape, or a `.one` range that does not start at zero, is the
    /// NON-prefix shape a composing discipline whose occupancy is not linear
    /// (`Buffer.Ring`) bulk-syncs via the settable `initialization` ledger
    /// (`Store.Ledgered.Protocol`, ratified 2026-06-10). Consumers that present or
    /// derive-from the region as a single contiguous run must not do so while this
    /// is `false`.
    @inlinable
    public var isPrefixShaped: Bool {
        switch self {
        case .empty:
            return true

        case .one(let range):
            return range.lowerBound == .zero

        case .two:
            return false
        }
    }
}

// MARK: - Range Iteration

extension Store.Initialization where Element: ~Copyable & ~Escapable {
    /// Calls `body` once for each initialized range.
    ///
    /// For `.empty`, `body` is never called.
    /// For `.one`, `body` is called once.
    /// For `.two`, `body` is called twice (first, then second).
    @inlinable
    public func forEach(
        _ body: (Swift.Range<Index<Element>>) -> Void
    ) {
        switch self {
        case .empty: break
        case .one(let range): body(range)

        case .two(let first, let second):
            body(first)
            body(second)
        }
    }
}

extension Store.Initialization where Element: ~Copyable & ~Escapable {
    /// Calls `body` for each initialized range with its linear destination offset.
    ///
    /// Ranges are visited in order, and the offset advances by each range's
    /// count. This packs disjoint ranges into contiguous linear positions.
    ///
    /// ```swift
    /// // .two(first: [6,8), second: [0,3)) with 5 elements:
    /// //   body([6,8), offset: 0)   — first 2 elements
    /// //   body([0,3), offset: 2)   — next 3 elements
    /// ```
    @inlinable
    public func linearize(
        _ body: (Swift.Range<Index<Element>>, _ offset: Index<Element>) -> Void
    ) {
        var offset: Index<Element> = .zero
        forEach { range in
            body(range, offset)
            offset += range.count
        }
    }
}

// MARK: - Factories

extension Store.Initialization where Element: ~Copyable & ~Escapable {
    /// Creates initialization state for a contiguous range starting at zero.
    ///
    /// This is the common case for linear buffers where elements occupy
    /// slots 0..<count.
    ///
    /// - Parameter count: The number of initialized slots.
    /// - Returns: Initialization state covering the slots `0..<count`.
    @inlinable
    public static func linear(count: Index<Element>.Count) -> Self {
        guard count > .zero else { return .empty }
        return .one(Swift.Range<Index<Element>>(start: .zero, count: count))
    }
}
