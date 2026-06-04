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

// MARK: - Pinned span surface (forwarders to the leaf)
//
// The no-argument `span` comes GENERICALLY from the Contiguous: Span.Protocol
// conditional conformance (the substrate vends it). The caller-asserted and
// mutable forms below are leaf-concrete (the form-α method class — concrete
// all the way down, never a generic seam).

extension Storage.Contiguous where Element: ~Copyable, Substrate == Memory.Heap<Element> {
    /// Mutable span over the initialized prefix. See `Memory.Heap.mutableSpan`.
    @inlinable
    public var mutableSpan: Swift.MutableSpan<Element> {
        @_lifetime(&self)
        mutating get {
            _substrate.mutableSpan
        }
    }

    /// Read-only span over the first `count` slots (caller-asserted).
    /// See `Memory.Heap.span(count:)`.
    @_lifetime(borrow self)
    @inlinable
    public borrowing func span(count: Index<Element>.Count) -> Swift.Span<Element> {
        _substrate.span(count: count)
    }

    /// Mutable span over the first `count` slots (caller-asserted).
    /// See `Memory.Heap.mutableSpan(count:)`.
    @_lifetime(&self)
    @inlinable
    public mutating func mutableSpan(count: Index<Element>.Count) -> Swift.MutableSpan<Element> {
        _substrate.mutableSpan(count: count)
    }

    /// Read-only span over the slots in `range` (caller-asserted).
    /// See `Memory.Heap.span(range:)`.
    @_lifetime(borrow self)
    @inlinable
    public borrowing func span(range: Swift.Range<Index<Element>>) -> Swift.Span<Element> {
        _substrate.span(range: range)
    }

    /// Whole-region append cursor over `[0, capacity)`. See `Memory.Heap.outputSpan`.
    @inlinable
    public var outputSpan: Swift.OutputSpan<Element> {
        @_lifetime(&self)
        _modify {
            yield &_substrate.outputSpan
        }
        @_lifetime(borrow self)
        _read {
            yield _substrate.outputSpan
        }
    }

    /// Bounded uninitialized-tail append region.
    /// See `Memory.Heap.withOutputSpan(addingCapacity:_:)`.
    @inlinable
    public mutating func withOutputSpan<R: ~Copyable, E: Swift.Error>(
        addingCapacity: Index<Element>.Count,
        _ body: (inout Swift.OutputSpan<Element>) throws(E) -> R
    ) throws(E) -> R {
        try _substrate.withOutputSpan(addingCapacity: addingCapacity, body)
    }

    /// Unsafe read access for C interop. See `Memory.Heap.withUnsafeBufferPointer(_:)`.
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        try _substrate.withUnsafeBufferPointer(body)
    }
}
