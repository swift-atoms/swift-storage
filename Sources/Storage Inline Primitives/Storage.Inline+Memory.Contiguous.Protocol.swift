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
public import Memory_Primitives_Core

// MARK: - Span / MutableSpan (~Copyable)

extension Storage.Inline where Element: ~Copyable {
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
    public var span: Span<Element> {
        @_lifetime(borrow self)
        borrowing get {
            let span = unsafe Span(
                _unsafeStart: pointer(at: .zero),
                count: initialization.count
            )
            return unsafe _overrideLifetime(span, borrowing: self)
        }
    }

    /// Safe, bounds-checked write access to contiguous storage.
    ///
    /// Returns a `MutableSpan` that exclusively borrows `self`, preventing
    /// concurrent access.
    ///
    /// - Precondition: Storage must be linearly initialized.
    /// - Complexity: O(1)
    @inlinable
    public var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        mutating get {
            let span = unsafe MutableSpan(
                _unsafeStart: UnsafeMutablePointer(mutating: pointer(at: .zero)),
                count: initialization.count
            )
            return unsafe _overrideLifetime(span, mutating: &self)
        }
    }
}

// MARK: - Memory.Contiguous.Protocol Conformance

extension Storage.Inline: Memory.Contiguous.`Protocol` {
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
            count: initialization.count
        ))
    }
}

// MARK: - Unsafe Mutable Access (Copyable)

extension Storage.Inline where Element: Copyable {
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
    public mutating func withUnsafeMutableBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeMutableBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        return try unsafe body(UnsafeMutableBufferPointer(
            start: UnsafeMutablePointer(mutating: pointer(at: .zero)),
            count: initialization.count
        ))
    }
}
