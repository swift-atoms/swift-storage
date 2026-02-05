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

// MARK: - Computed Properties

extension Storage.Initialization where Element: ~Copyable {
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

extension Storage.Initialization where Element: ~Copyable {
    /// Creates initialization state for a contiguous range starting at zero.
    ///
    /// This is the common case for linear buffers where elements occupy
    /// slots 0..<count.
    ///
    /// - Parameter count: The number of initialized slots.
    @inlinable
    public static func linear(count: Index<Element>.Count) -> Self {
        guard count > .zero else { return .empty }
        return .one(Swift.Range<Index<Element>>(start: .zero, count: count))
    }
}
