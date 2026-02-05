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

// MARK: - Copyable Extensions for Inline Storage

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
    public func copy(range: Swift.Range<Index<Element>>, to destination: Storage.Heap<Element>) {
        guard !range.isEmpty else { return }
        let count = Int(range.count.rawValue.rawValue)
        let srcPtr = unsafe pointer(at: range.lowerBound)
        unsafe destination.withUnsafeMutablePointerToElements { dst in
            unsafe dst.initialize(from: srcPtr, count: count)
        }
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
        try unsafe withUnsafePointer(to: _storage) { base throws(E) in
            let raw = unsafe UnsafeRawPointer(base)
            let startOffset = Int(range.lowerBound.rawValue.rawValue) * MemoryLayout<Element>.stride
            let ptr = unsafe raw.advanced(by: startOffset).assumingMemoryBound(to: Element.self)
            let count = Int(bitPattern: range.count)
            let span = unsafe Span(_unsafeStart: ptr, count: count)
            return try body(span)
        }
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
        try unsafe withUnsafeMutablePointer(to: &_storage) { base throws(E) in
            let raw = UnsafeMutableRawPointer(base)
            let startOffset = Int(range.lowerBound.rawValue.rawValue) * MemoryLayout<Element>.stride
            let ptr = unsafe raw.advanced(by: startOffset).assumingMemoryBound(to: Element.self)
            let count = Int(bitPattern: range.count)
            var span = unsafe MutableSpan(_unsafeStart: ptr, count: count)
            return try body(&span)
        }
    }
}
