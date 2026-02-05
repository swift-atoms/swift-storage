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
import Standard_Library_Extensions

// MARK: - Copyable Extensions

extension Storage.Heap where Element: Copyable {
    /// Creates a copy of this storage with all initialized elements.
    ///
    /// Handles all initialization patterns (.empty, .one, .two).
    ///
    /// - Returns: A new storage instance with copied elements.
    @inlinable
    public func copy() -> Storage.Heap {
        let init_ = self.initialization
        let count = init_.count
        let new = Storage.Heap.create(minimumCapacity: count)
        new.initialization = .linear(count: count)

        guard count > .zero else { return new }

        func copySpan(_ range: Swift.Range<Index<Element>>, dstStart: inout Index<Element>) {
            guard !range.isEmpty else { return }
            let spanCount = Int(range.count.rawValue.rawValue)
            _ = unsafe withUnsafeMutablePointerToElements { src in
                let srcOffset = Index<Element>.Offset(fromZero: range.lowerBound)
                let srcStart = unsafe UnsafePointer(src + srcOffset)
                unsafe new.withUnsafeMutablePointerToElements { dst in
                    let dstOffset = Index<Element>.Offset(fromZero: dstStart)
                    unsafe (dst + dstOffset).initialize(from: srcStart, count: spanCount)
                }
            }
            dstStart = Index(Ordinal(dstStart.rawValue.rawValue + UInt(spanCount)))
        }

        var dstSlot: Index<Element> = .zero
        switch init_ {
        case .empty:
            break
        case .one(let range):
            copySpan(range, dstStart: &dstSlot)
        case .two(let first, let second):
            copySpan(first, dstStart: &dstSlot)
            copySpan(second, dstStart: &dstSlot)
        }

        return new
    }

    /// Copies all initialized elements to destination storage.
    ///
    /// Elements are copied to linear positions starting at slot 0 in the destination.
    /// Handles all initialization patterns (.empty, .one, .two).
    ///
    /// - Parameter destination: The destination storage.
    /// - Precondition: Destination must have sufficient capacity.
    @inlinable
    public func copy(to destination: Storage.Heap) {
        let init_ = self.initialization

        func copySpan(_ range: Swift.Range<Index<Element>>, dstStart: inout Index<Element>) {
            guard !range.isEmpty else { return }
            let spanCount = Int(range.count.rawValue.rawValue)
            _ = unsafe withUnsafeMutablePointerToElements { src in
                let srcOffset = Index<Element>.Offset(fromZero: range.lowerBound)
                let srcStart = unsafe UnsafePointer(src + srcOffset)
                unsafe destination.withUnsafeMutablePointerToElements { dst in
                    let dstOffset = Index<Element>.Offset(fromZero: dstStart)
                    unsafe (dst + dstOffset).initialize(from: srcStart, count: spanCount)
                }
            }
            dstStart = Index(Ordinal(dstStart.rawValue.rawValue + UInt(spanCount)))
        }

        var dstSlot: Index<Element> = .zero
        switch init_ {
        case .empty:
            break
        case .one(let range):
            copySpan(range, dstStart: &dstSlot)
        case .two(let first, let second):
            copySpan(first, dstStart: &dstSlot)
            copySpan(second, dstStart: &dstSlot)
        }
    }

    /// Copies elements in the given range to linear positions in the destination.
    ///
    /// Uses bulk initialization for better performance on contiguous ranges.
    ///
    /// - Parameters:
    ///   - range: The contiguous range of slots to copy from.
    ///   - destination: The destination storage.
    /// - Precondition: All slots in the range must contain initialized elements.
    /// - Precondition: Destination slots 0..<range.count must be uninitialized.
    @inlinable
    public func copy(range: Swift.Range<Index<Element>>, to destination: Storage.Heap) {
        guard !range.isEmpty else { return }
        let count = Int(range.count.rawValue.rawValue)
        _ = unsafe withUnsafeMutablePointerToElements { src in
            let srcOffset = Index<Element>.Offset(fromZero: range.lowerBound)
            let srcStart = unsafe UnsafePointer(src + srcOffset)
            unsafe destination.withUnsafeMutablePointerToElements { dst in
                unsafe dst.initialize(from: srcStart, count: count)
            }
        }
    }
}

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
        try unsafe withUnsafeMutablePointerToElements { base throws(E) in
            let startOffset = Index<Element>.Offset(fromZero: range.lowerBound)
            let count = Int(bitPattern: range.count)
            let span = unsafe Span(
                _unsafeStart: UnsafePointer(base + startOffset),
                count: count
            )
            return try body(span)
        }
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
        try unsafe withUnsafeMutablePointerToElements { base throws(E) in
            let startOffset = Index<Element>.Offset(fromZero: range.lowerBound)
            let count = Int(bitPattern: range.count)
            var span = unsafe MutableSpan(
                _unsafeStart: base + startOffset,
                count: count
            )
            return try body(&span)
        }
    }
}
