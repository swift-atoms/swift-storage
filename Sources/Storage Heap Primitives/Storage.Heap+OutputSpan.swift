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

import Affine_Primitives_Standard_Library_Integration
public import Index_Primitives
import Ordinal_Primitives_Standard_Library_Integration
public import Storage_Initialization_Primitives
public import Storage_Primitive

// MARK: - OutputSpan (whole-region append into the uninitialized tail — §4 Span-first surface)

extension Storage.Heap where Element: ~Copyable {
    /// A whole-region `OutputSpan` over `[0, capacity)` for appending into the
    /// **uninitialized tail**, with the initialized prefix `[0, count)` presented
    /// as already-initialized.
    ///
    /// This is the Span-first whole-region surface for the north-star
    /// `Storage.`Protocol`` modernization (migration plan §4). Buffer disciplines
    /// (`Buffer.Linear`) drive bulk initialize / append / edit through it; their
    /// own closure API forwards into this property:
    ///
    /// ```swift
    /// // inside Buffer.Linear.edit / append / init:
    /// try body(&storage.outputSpan)   // body appends; the new count commits on return
    /// ```
    ///
    /// `OutputSpan` is the safe modern API for the uninitialized-tail case: it
    /// tracks `initializedCount` and bounds every append, so no raw
    /// `UnsafeMutableBufferPointer` is exposed across the package boundary. The
    /// only raw pointer is `withUnsafeMutablePointerToElements` *inside* this
    /// body — the `ManagedBuffer` tail bridge — encapsulated at the lowest level.
    /// (This is the Span-first replacement for the earlier raw
    /// `withUnsafeMutableCapacityRegion` escape-hatch.)
    ///
    /// Property-based per [MEM-SPAN-001]; `OutputSpan` is `~Escapable`, so the
    /// type system scopes it and no `with*` closure is needed. The accessor is
    /// `_read` / `_modify`:
    /// - `_modify` exposes the appendable span under exclusive `&self`; on its
    ///   `defer` it `finalize`s the span (relinquishing it *without*
    ///   deinitializing the live region) and writes the committed count back into
    ///   the header. The `defer` runs on **both** the normal and the throwing
    ///   exit, so a throwing initializer commits whatever it appended and never
    ///   double-deinitializes (verified on Apple Swift 6.3.2 with pre-existing
    ///   elements).
    /// - `_read` exists only to satisfy Swift's accessor-pairing rule (an append
    ///   cursor has no meaningful non-mutating use). It also `finalize`s in
    ///   `defer`, so a stray non-mutating access never deinitializes the live
    ///   region.
    ///
    /// - Precondition: Storage must be linearly initialized (`.empty` or
    ///   `.one(0..<count)`). On return the initialization state is set to
    ///   `.linear(count:)` from the span's committed count.
    /// - Complexity: O(1) plus the work the caller performs through the span.
    @inlinable
    public var outputSpan: Swift.OutputSpan<Element> {
        @_lifetime(&self)
        _modify {
            let capacity = _buffer.capacity
            let base = unsafe _buffer.withUnsafeMutablePointerToElements { unsafe $0 }
            var output = unsafe Swift.OutputSpan(
                buffer: unsafe UnsafeMutableBufferPointer(start: base, count: capacity),
                initializedCount: Int(bitPattern: _buffer.header.count)
            )
            defer {
                let committed = unsafe output.finalize(
                    for: unsafe UnsafeMutableBufferPointer(start: base, count: capacity)
                )
                output = Swift.OutputSpan()
                _buffer.header.initialization = .linear(count: Index<Element>.Count(UInt(committed)))
            }
            yield &output
        }
        @_lifetime(borrow self)
        _read {
            let capacity = _buffer.capacity
            let base = unsafe _buffer.withUnsafeMutablePointerToElements { unsafe $0 }
            var output = unsafe Swift.OutputSpan(
                buffer: unsafe UnsafeMutableBufferPointer(start: base, count: capacity),
                initializedCount: Int(bitPattern: _buffer.header.count)
            )
            defer {
                _ = unsafe output.finalize(
                    for: unsafe UnsafeMutableBufferPointer(start: base, count: capacity)
                )
                output = Swift.OutputSpan()
            }
            yield output
        }
    }

    /// Invokes `body` with an `OutputSpan<Element>` over exactly `addingCapacity`
    /// uninitialized slots at the tail, starting at the current initialized count.
    ///
    /// Unlike ``outputSpan`` (whose region is the whole `[0, capacity)`), this
    /// closure form bounds the span to *exactly* `addingCapacity` — preserving the
    /// `Buffer.Linear.append(addingCapacity:initializingWith:)` contract that the
    /// closure sees a region sized to the requested capacity (e.g. `addingCapacity:
    /// 0` yields a zero-capacity span). A closure is the right shape here — a
    /// bounded, uninitialized-tail *initialization* region needs a scope for
    /// `finalize` + count write-back, matching `Array.append(addingCapacity:
    /// initializingWith:)`; the property form cannot carry the bound.
    ///
    /// On return (normal OR throwing) the appended elements are committed and the
    /// header's initialization advances to `count + committedAppends`. The only
    /// raw pointer is the `ManagedBuffer` tail bridge inside this body.
    ///
    /// - Precondition: the storage's `initialization` reflects the caller's live
    ///   count (the tail starts at `initialization.count`), and
    ///   `initialization.count + addingCapacity <= capacity`.
    /// - Parameters:
    ///   - addingCapacity: The exact number of uninitialized tail slots to expose.
    ///   - body: Receives the bounded `OutputSpan`; appends commit on return.
    /// - Returns: The value returned by `body`.
    /// - Throws: Any error thrown by `body`.
    @inlinable
    public mutating func withOutputSpan<R: ~Copyable, E: Swift.Error>(
        addingCapacity: Index<Element>.Count,
        _ body: (inout Swift.OutputSpan<Element>) throws(E) -> R
    ) throws(E) -> R {
        let start = _buffer.header.count
        let base = unsafe _buffer.withUnsafeMutablePointerToElements {
            unsafe $0 + Index<Element>.Offset(fromZero: start.map(Ordinal.init))
        }
        var span = unsafe Swift.OutputSpan(
            buffer: unsafe UnsafeMutableBufferPointer(start: base, count: addingCapacity),
            initializedCount: 0
        )
        defer {
            let committed = unsafe span.finalize(
                for: unsafe UnsafeMutableBufferPointer(start: base, count: addingCapacity)
            )
            span = Swift.OutputSpan()
            _buffer.header.initialization = .linear(count: start + Index<Element>.Count(UInt(committed)))
        }
        return try body(&span)
    }
}
