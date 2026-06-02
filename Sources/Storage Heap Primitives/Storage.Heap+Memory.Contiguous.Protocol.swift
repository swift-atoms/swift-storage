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
public import Memory_Contiguous_Primitives
public import Memory_Primitives_Standard_Library_Integration

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
                count: _buffer.header.count
            )
            return unsafe _overrideLifetime(span, borrowing: self)
        }
    }

    /// Safe, bounds-checked mutable access to the initialized region.
    ///
    /// Returns a `MutableSpan` over elements `0..<count` that exclusively borrows
    /// `self` (`@_lifetime(&self)`), so two live mutable spans to the same storage
    /// cannot coexist. Property-based per [MEM-SPAN-001] — `MutableSpan` is
    /// `~Escapable`, so the type system scopes it and no `with*` closure is needed.
    ///
    /// This is the Span-first replacement for the former closure-based
    /// `withMutableSpan(_:)`, and — because mutation flows through the exclusive
    /// `&self` borrow rather than a Copyable copy — it is available for `~Copyable`
    /// elements, matching `Storage.Inline.mutableSpan`.
    ///
    /// - Precondition: Storage must be linearly initialized (`.empty` or `.one(0..<n)`).
    /// - Complexity: O(1)
    @inlinable
    public var mutableSpan: Swift.MutableSpan<Element> {
        @_lifetime(&self)
        mutating get {
            let base = unsafe _buffer.withUnsafeMutablePointerToElements { unsafe $0 }
            let span = unsafe Swift.MutableSpan(_unsafeStart: base, count: _buffer.header.count)
            return unsafe _overrideLifetime(span, mutating: &self)
        }
    }

    /// Read-only span over the first `count` slots, which the caller asserts are
    /// initialized.
    ///
    /// For consumers whose *own* element count is the source of truth and may
    /// differ from `storage.initialization.count` (e.g. `Buffer.Linear`, whose
    /// header count is authoritative and is only re-synced into the storage's
    /// `initialization` at growth, not after every per-slot operation), the
    /// no-argument ``span`` is not appropriate — it would report the storage's own
    /// (possibly stale) count. This count-bounded form is the typed,
    /// pointer-free replacement for the previous `Span(_unsafeStart:
    /// pointer(at: .zero), count: callerCount)`.
    ///
    /// - Precondition: slots `[0, count)` are initialized and `count <= capacity`.
    /// - Complexity: O(1)
    @_lifetime(borrow self)
    @inlinable
    public borrowing func span(count: Index<Element>.Count) -> Swift.Span<Element> {
        let base = unsafe _buffer.withUnsafeMutablePointerToElements { unsafe $0 }
        let span = unsafe Swift.Span(_unsafeStart: base, count: count)
        return unsafe _overrideLifetime(span, borrowing: self)
    }

    /// Mutable span over the first `count` slots, which the caller asserts are initialized.
    ///
    /// Exclusive `&self` (so it cannot alias). The mutable counterpart to
    /// ``span(count:)``; see that method for why a caller-supplied count is needed
    /// instead of the no-argument ``mutableSpan``.
    ///
    /// - Precondition: slots `[0, count)` are initialized and `count <= capacity`.
    /// - Complexity: O(1)
    @_lifetime(&self)
    @inlinable
    public mutating func mutableSpan(count: Index<Element>.Count) -> Swift.MutableSpan<Element> {
        let base = unsafe _buffer.withUnsafeMutablePointerToElements { unsafe $0 }
        let span = unsafe Swift.MutableSpan(_unsafeStart: base, count: count)
        return unsafe _overrideLifetime(span, mutating: &self)
    }

    /// Read-only span over the slots in `range`, which the caller asserts are
    /// initialized.
    ///
    /// Range-based counterpart to ``span(count:)`` for consumers that access
    /// disjoint sub-ranges rather than a `[0, count)` prefix — e.g. `Buffer.Ring`,
    /// whose two wrap-around segments are each a contiguous range and whose
    /// `Sequence` returns the segment spans (so they cannot be served by a
    /// closure-scoped accessor). The typed, pointer-free replacement for
    /// `Span(_unsafeStart: pointer(at: range.lowerBound), count: range.count)`.
    ///
    /// - Precondition: every slot in `range` is initialized and within capacity.
    /// - Complexity: O(1)
    @_lifetime(borrow self)
    @inlinable
    public borrowing func span(range: Swift.Range<Index<Element>>) -> Swift.Span<Element> {
        let base = unsafe _buffer.withUnsafeMutablePointerToElements {
            unsafe $0 + Index<Element>.Offset(fromZero: range.lowerBound)
        }
        let span = unsafe Swift.Span(_unsafeStart: base, count: range.count)
        return unsafe _overrideLifetime(span, borrowing: self)
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
    /// - Throws: Any error thrown by `body`.
    /// - Precondition: Storage must be linearly initialized.
    /// - Complexity: O(1) plus the complexity of `body`.
    /// - Warning: The buffer pointer is only valid within `body`.
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        return try unsafe body(
            UnsafeBufferPointer(
                start: pointer(at: .zero),
                count: _buffer.header.initialization.count
            )
        )
    }
}

// MARK: - Type-Specific Mutable Access

extension Storage.Heap where Element: Copyable {
    /// Unsafe write access for C interop with unannotated APIs.
    ///
    /// Provides mutable raw pointer access for C functions that lack
    /// lifetime annotations.
    ///
    /// - Parameter body: A closure that receives the mutable buffer pointer.
    /// - Returns: The value returned by `body`.
    /// - Throws: Any error thrown by `body`.
    /// - Precondition: Storage must be linearly initialized.
    /// - Complexity: O(1) plus the complexity of `body`.
    /// - Warning: The buffer pointer is only valid within `body`.
    @inlinable
    public func withUnsafeMutableBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeMutableBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        return try unsafe body(
            UnsafeMutableBufferPointer(
                start: pointer(at: .zero),
                count: _buffer.header.initialization.count
            )
        )
    }
}
