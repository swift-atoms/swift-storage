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

import Memory_Primitives_Core

// MARK: - Memory.Contiguous.Protocol Conformance

extension Storage.Heap: Memory.Contiguous.`Protocol` {
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
        get {
            let (ptr, count) = unsafe withUnsafeMutablePointerToElements { base in
                (unsafe UnsafePointer(base), Int(bitPattern: header.count))
            }
            let span = unsafe Span(_unsafeStart: ptr, count: count)
            return unsafe _overrideLifetime(span, borrowing: self)
        }
    }

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
        let count = Int(bitPattern: header.initialization.count)
        return try unsafe withUnsafeMutablePointerToElements { base throws(E) in
            let buffer = unsafe UnsafeBufferPointer(start: base, count: count)
            return try unsafe body(buffer)
        }
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
        _ body: (inout MutableSpan<Element>) throws(E) -> R
    ) throws(E) -> R {
        let count = Int(bitPattern: header.initialization.count)
        return try unsafe withUnsafeMutablePointerToElements { base throws(E) in
            var span = unsafe MutableSpan(_unsafeStart: base, count: count)
            return try body(&span)
        }
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
        let count = Int(bitPattern: header.initialization.count)
        return try unsafe withUnsafeMutablePointerToElements { base throws(E) in
            let buffer = unsafe UnsafeMutableBufferPointer(start: base, count: count)
            return try unsafe body(buffer)
        }
    }
}
