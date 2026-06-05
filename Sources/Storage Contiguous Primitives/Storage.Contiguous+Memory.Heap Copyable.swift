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

// MARK: - Span access (Copyable elements; heap-pinned forwarders to the leaf)
//
// CoW (`isUnique` / `ensureUnique`) is the generic Memory.Unique forwarder in
// `Storage.Contiguous+Memory.Unique.swift`; the span accessors below stay pinned to the
// heap leaf because they reach `Memory.Heap`'s pointer surface directly.

extension Storage.Contiguous where Element: Copyable, Substrate == Memory.Heap<Element> {
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
