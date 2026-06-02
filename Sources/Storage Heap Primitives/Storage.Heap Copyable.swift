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
public import Storage_Initialization_Primitives
public import Storage_Primitive

// MARK: - Copy-on-Write (Copyable elements)

extension Storage.Heap where Element: Copyable {
    /// Whether this façade is the sole owner of its backing buffer.
    ///
    /// Backed by `isKnownUniquelyReferenced(&_buffer)`. Uniqueness is a runtime
    /// question only on the `Copyable` path: a value-copied `Copyable` Heap shares
    /// its buffer until the first mutation triggers CoW. (A `~Copyable` Heap is
    /// statically unique — uncopyable, buffer never exposed — so it carries no
    /// `isUnique`/`ensureUnique` surface at all.)
    @inlinable
    public var isUnique: Bool {
        mutating get { isKnownUniquelyReferenced(&_buffer) }
    }

    /// Ensures this façade is the sole owner of its backing buffer, deep-copying
    /// the initialized elements into a fresh allocation when the buffer is shared.
    ///
    /// This is the copy-on-write primitive for the value-type façade, the same
    /// mechanism `Swift.Array` and `Buffer.Linear.ensureUnique()` use: a copy is
    /// taken only when `isKnownUniquelyReferenced(&_buffer)` is `false` (the Heap
    /// was value-copied and now shares its backing). After the copy, the two Heap
    /// values own independent buffers, so a subsequent mutation through `self`
    /// leaves the other copy untouched — value semantics.
    ///
    /// CoW lives only on the `Copyable` path. A `~Copyable` Heap is statically
    /// unique (uncopyable, buffer never exposed), so it has no `ensureUnique` at
    /// all — there is nothing to restore.
    ///
    /// The copy preserves the exact initialization layout (including disjoint
    /// `.two` ring spans) by copying elements at their original slot positions,
    /// rather than linearizing — a Heap that was a wrapped ring stays a wrapped
    /// ring after CoW.
    ///
    /// - Returns: `true` if a copy was made to restore uniqueness.
    @inlinable
    @discardableResult
    public mutating func ensureUnique() -> Bool {
        guard !isKnownUniquelyReferenced(&_buffer) else { return false }
        let layout = _buffer.header.initialization
        let fresh = Storage.Heap.create(minimumCapacity: capacity)
        layout.forEach { range in
            guard !range.isEmpty else { return }
            unsafe fresh.pointer(at: range.lowerBound)
                .initialize(from: pointer(at: range.lowerBound), count: range.count)
        }
        fresh.initialization = layout
        self = fresh
        return true
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
        return try body(
            unsafe Span(
                _unsafeStart: pointer(at: range.lowerBound),
                count: range.count
            )
        )
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
        var span = unsafe MutableSpan(
            _unsafeStart: pointer(at: range.lowerBound),
            count: range.count
        )
        return try body(&span)
    }
}
