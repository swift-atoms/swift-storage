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

public import Storage_Primitives_Core

// MARK: - Range-Based Span Access

extension Storage.Heap where Element: Copyable {
    /// Provides read-only access to elements in the specified slot range.
    ///
    /// The span is valid only for the duration of the closure. Use this for
    /// accessing arbitrary ranges (e.g., ring buffer segments).
    ///
    /// For linear access (0..<count), prefer the `span` property instead.
    ///
    /// - Parameters:
    ///   - range: The contiguous range of slots to access.
    ///   - body: A closure that receives the span.
    /// - Returns: The value returned by the closure.
    /// - Throws: Rethrows any error thrown by the closure.
    /// - Precondition: All slots in the range must contain initialized elements.
    @inlinable
    public func withSpan<R, E: Swift.Error>(
        _ range: Swift.Range<Index<Element>>,
        _ body: (Span<Element>) throws(E) -> R
    ) throws(E) -> R {
        return try body(unsafe Span(
            _unsafeStart: pointer(at: range.lowerBound),
            count: range.count
        ))
    }

    /// Provides mutable access to elements in the specified slot range.
    ///
    /// The span is valid only for the duration of the closure. Use this for
    /// accessing arbitrary ranges (e.g., ring buffer segments).
    ///
    /// For linear access (0..<count), prefer the `withMutableSpan(_:)` method instead.
    ///
    /// - Parameters:
    ///   - range: The contiguous range of slots to access.
    ///   - body: A closure that receives the mutable span.
    /// - Returns: The value returned by the closure.
    /// - Throws: Rethrows any error thrown by the closure.
    /// - Precondition: All slots in the range must contain initialized elements.
    @inlinable
    public func withMutableSpan<R, E: Swift.Error>(
        _ range: Swift.Range<Index<Element>>,
        _ body: (inout MutableSpan<Element>) throws(E) -> R
    ) throws(E) -> R {
        var span = unsafe MutableSpan(
            _unsafeStart: pointer(at: range.lowerBound),
            count: range.count
        )
        return try body(&span)
    }
}
