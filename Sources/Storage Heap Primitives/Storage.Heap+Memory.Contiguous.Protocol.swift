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


// MARK: - Span (~Copyable)

extension Storage.Heap where Element: ~Copyable {
    /// Safe, bounds-checked read access to contiguous storage.
    ///
    /// Returns a `Span` over elements `0..<count` where count is derived from
    /// the initialization state.
    ///
    /// - Precondition: Storage must be linearly initialized (`.empty` or `.one(0..<n)`).
    ///   Using this property with non-linear initialization (`.two`) results in
    ///   undefined behavior as the elements are not contiguous from zero.
    /// - Complexity: O(1)
    @inlinable
    public var span: Swift.Span<Element> {
        @_lifetime(borrow self)
        get {
            let span = unsafe Swift.Span(
                _unsafeStart: pointer(at: .zero),
                count: Int(bitPattern: header.count)
            )
            return unsafe _overrideLifetime(span, borrowing: self)
        }
    }
}

// MARK: - Memory.Contiguous.Protocol Conformance

extension Storage.Heap: Memory.Contiguous.`Protocol` {
    /// Unsafe read access for C interop with unannotated APIs.
    ///
    /// Provides raw pointer access to initialized elements for C functions
    /// that lack lifetime annotations.
    ///
    /// - Parameter body: A closure that receives the buffer pointer.
    /// - Returns: The value returned by `body`.
    /// - Precondition: Storage must be linearly initialized.
    /// - Complexity: O(1) plus the complexity of `body`.
    /// - Warning: The buffer pointer is only valid within `body`.
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        return try unsafe body(UnsafeBufferPointer(
            start: pointer(at: .zero),
            count: Int(bitPattern: header.initialization.count)
        ))
    }
}

// MARK: - Type-Specific Mutable Access

extension Storage.Heap where Element: Copyable {
    /// Safe, bounds-checked write access to contiguous storage.
    ///
    /// Provides mutable span access via closure since classes cannot have
    /// `mutating get` properties.
    ///
    /// - Parameter body: A closure that receives the mutable span.
    /// - Returns: The value returned by `body`.
    /// - Precondition: Storage must be linearly initialized.
    /// - Complexity: O(1) plus the complexity of `body`.
    @inlinable
    public func withMutableSpan<R, E: Swift.Error>(
        _ body: (inout Swift.MutableSpan<Element>) throws(E) -> R
    ) throws(E) -> R {
        var span = unsafe MutableSpan(
            _unsafeStart: pointer(at: .zero),
            count: Int(bitPattern: header.initialization.count)
        )
        return try body(&span)
    }

    /// Unsafe write access for C interop with unannotated APIs.
    ///
    /// Provides mutable raw pointer access for C functions that lack
    /// lifetime annotations.
    ///
    /// - Parameter body: A closure that receives the mutable buffer pointer.
    /// - Returns: The value returned by `body`.
    /// - Precondition: Storage must be linearly initialized.
    /// - Complexity: O(1) plus the complexity of `body`.
    /// - Warning: The buffer pointer is only valid within `body`.
    @inlinable
    public func withUnsafeMutableBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeMutableBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        return try unsafe body(UnsafeMutableBufferPointer(
            start: pointer(at: .zero),
            count: Int(bitPattern: header.initialization.count)
        ))
    }
}
