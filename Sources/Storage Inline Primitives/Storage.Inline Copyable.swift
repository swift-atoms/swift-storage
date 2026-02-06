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

// MARK: - Copy

extension Storage.Inline where Element: Copyable {
    /// Copies elements in range to linear positions in destination heap storage.
    ///
    /// Elements from the source range are placed at slots 0..<range.count in the
    /// destination storage.
    ///
    /// - Parameters:
    ///   - range: The contiguous range of slots to copy from.
    ///   - destination: The destination heap storage.
    /// - Precondition: All slots in the range must contain initialized elements.
    /// - Precondition: Destination slots 0..<range.count must be uninitialized.
    @inlinable
    public func copy(
        range: Swift.Range<Index<Element>>,
        to destination: Storage.Heap
    ) {
        guard !range.isEmpty else { return }
        unsafe destination.pointer(at: .zero)
            .initialize(from: pointer(at: range.lowerBound), count: range.count)
    }

    /// Copies all initialized elements to destination heap storage.
    ///
    /// Elements are copied to linear positions starting at slot 0 in the destination.
    /// Under linear discipline, this copies the range `0..<count`.
    ///
    /// - Parameter destination: The destination heap storage.
    /// - Precondition: Destination must have sufficient capacity.
    /// - Precondition: Storage must be using linear discipline (contiguous from zero).
    /// - Note: Caller must update destination's initialization state.
    @inlinable
    public func copy(to destination: Storage.Heap) {
        let count = initialization.count
        guard count > .zero else { return }
        let range: Swift.Range<Index<Element>> = .zero ..< count.map(Ordinal.init)
        copy(range: range, to: destination)
    }
}

// MARK: - Range-Based Span Access

extension Storage.Inline where Element: Copyable {
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
            count: Int(bitPattern: range.count)
        ))
    }

    /// Provides mutable access to elements in the specified slot range.
    ///
    /// The span is valid only for the duration of the closure. Use this for
    /// accessing arbitrary ranges (e.g., ring buffer segments).
    ///
    /// For linear access (0..<count), prefer the `mutableSpan` property instead.
    ///
    /// - Parameters:
    ///   - range: The contiguous range of slots to access.
    ///   - body: A closure that receives the mutable span.
    /// - Returns: The value returned by the closure.
    /// - Throws: Rethrows any error thrown by the closure.
    /// - Precondition: All slots in the range must contain initialized elements.
    @inlinable
    public mutating func withMutableSpan<R, E: Swift.Error>(
        _ range: Swift.Range<Index<Element>>,
        _ body: (inout MutableSpan<Element>) throws(E) -> R
    ) throws(E) -> R {
        var span = unsafe MutableSpan(
            _unsafeStart: UnsafeMutablePointer(mutating: pointer(at: range.lowerBound)),
            count: Int(bitPattern: range.count)
        )
        return try body(&span)
    }
}
