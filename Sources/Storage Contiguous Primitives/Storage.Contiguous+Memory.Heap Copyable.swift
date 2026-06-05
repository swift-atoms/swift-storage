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
public import Memory_Heap_Primitives
public import Storage_Primitive

// MARK: - Copy-on-Write (Copyable elements; pinned forwarders to the leaf)

extension Storage.Contiguous where Element: Copyable, Substrate == Memory.Heap<Element> {
    /// Whether this storage is the sole owner of its backing buffer.
    ///
    /// Forwarded to the leaf's `isKnownUniquelyReferenced` probe. See
    /// `Memory.Heap.isUnique`.
    @inlinable
    public var isUnique: Bool {
        mutating get { _substrate.isUnique }
    }

    /// Ensures this storage is the sole owner of its backing buffer,
    /// deep-copying the initialized elements when shared.
    ///
    /// Forwarded to the leaf's occupancy-aware CoW primitive (the ledger and
    /// the elements copy together, leaf-side — including disjoint `.two` ring
    /// layouts at their original slots). See `Memory.Heap.ensureUnique()`.
    ///
    /// - Returns: `true` if a copy was made to restore uniqueness.
    @inlinable
    @discardableResult
    public mutating func ensureUnique() -> Bool {
        _substrate.ensureUnique()
    }

    /// Provides read-only access to elements in the specified slot range.
    ///
    /// See `Memory.Heap.withSpan(_:_:)`.
    @inlinable
    public func withSpan<R, E: Swift.Error>(
        _ range: Swift.Range<Index<Element>>,
        _ body: (Swift.Span<Element>) throws(E) -> R
    ) throws(E) -> R {
        try _substrate.withSpan(range, body)
    }

    /// Provides mutable access to elements in the specified slot range.
    ///
    /// See `Memory.Heap.withMutableSpan(_:_:)`.
    @inlinable
    public func withMutableSpan<R, E: Swift.Error>(
        _ range: Swift.Range<Index<Element>>,
        _ body: (inout Swift.MutableSpan<Element>) throws(E) -> R
    ) throws(E) -> R {
        try _substrate.withMutableSpan(range, body)
    }

    /// Unsafe write access for C interop with unannotated APIs.
    ///
    /// See `Memory.Heap.withUnsafeMutableBufferPointer(_:)`.
    @inlinable
    public func withUnsafeMutableBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeMutableBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        try _substrate.withUnsafeMutableBufferPointer(body)
    }
}
