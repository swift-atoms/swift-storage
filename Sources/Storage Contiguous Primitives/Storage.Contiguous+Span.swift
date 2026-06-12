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

// Span / MutableSpan / OutputSpan accessors — the prior `Memory.Heap+Span` / `+OutputSpan` re-homed
// to the Storage tier (where `Element` now lives). Same lifetimes (`@_lifetime`), same
// `_overrideLifetime` escape, same OutputSpan ledger-commit-on-`defer` contract. The architecture
// constraint is honored: Span / OutputSpan live around the Storage seam, never below the allocator.

public import Index_Primitives
public import Store_Initialization_Primitives
public import Span_Protocol_Primitives

extension Storage.Contiguous where Allocation: ~Copyable, Element: ~Copyable {
    /// Safe, bounds-checked read access over the initialized prefix `[0, count)`.
    @inlinable
    public var span: Swift.Span<Element> {
        @_lifetime(borrow self)
        get {
            let span = unsafe Swift.Span(_unsafeStart: _base, count: Int(bitPattern: count))
            return unsafe _overrideLifetime(span, borrowing: self)
        }
    }

    /// Safe, bounds-checked mutable access over `[0, count)` under an exclusive `&self` borrow.
    @inlinable
    public var mutableSpan: Swift.MutableSpan<Element> {
        @_lifetime(&self)
        mutating get {
            let span = unsafe Swift.MutableSpan(_unsafeStart: _base, count: Int(bitPattern: count))
            return unsafe _overrideLifetime(span, mutating: &self)
        }
    }

    /// A whole-region `OutputSpan` over `[0, capacity)` for appending into the uninitialized tail; on
    /// `defer` it `finalize`s and commits the new count into the ledger (`.linear(count:)`). The
    /// `defer` runs on both normal and throwing exit, so a throwing initializer commits whatever it
    /// appended and never double-deinitializes.
    @inlinable
    public var outputSpan: Swift.OutputSpan<Element> {
        @_lifetime(&self)
        _modify {
            let cap = Int(bitPattern: _capacity)
            var output = unsafe Swift.OutputSpan(
                buffer: unsafe UnsafeMutableBufferPointer(start: _base, count: cap),
                initializedCount: Int(bitPattern: count)
            )
            defer {
                let committed = unsafe output.finalize(
                    for: unsafe UnsafeMutableBufferPointer(start: _base, count: cap)
                )
                output = Swift.OutputSpan()
                _initialization = .linear(count: Index<Element>.Count(UInt(committed)))
            }
            yield &output
        }
        @_lifetime(borrow self)
        _read {
            let cap = Int(bitPattern: _capacity)
            var output = unsafe Swift.OutputSpan(
                buffer: unsafe UnsafeMutableBufferPointer(start: _base, count: cap),
                initializedCount: Int(bitPattern: count)
            )
            defer {
                _ = unsafe output.finalize(for: unsafe UnsafeMutableBufferPointer(start: _base, count: cap))
                output = Swift.OutputSpan()
            }
            yield output
        }
    }

    /// Invokes `body` with an `OutputSpan` over the uninitialized TAIL WINDOW
    /// `[count, count + addingCapacity)` — the budgeted append seam: the span's `capacity` is
    /// exactly `addingCapacity`, `isFull` fires when the budget is exhausted, and on both normal
    /// and throwing exit the appended elements are committed into the ledger
    /// (`.linear(count: count + appended)`).
    ///
    /// This is the windowed counterpart of the whole-region `outputSpan` accessor (the prior
    /// `Memory.Heap.withOutputSpan(addingCapacity:)` contract, restored at the Storage tier):
    /// a growable discipline (`Buffer.Linear`) grows first, then offers its initializer exactly
    /// the budget it promised. The window MUST fit — the caller has already ensured capacity.
    @inlinable
    public mutating func withOutputSpan<R: ~Copyable, Failure: Swift.Error>(
        addingCapacity budget: Index<Element>.Count,
        _ body: (inout Swift.OutputSpan<Element>) throws(Failure) -> R
    ) throws(Failure) -> R {
        let frontier = Int(bitPattern: count)
        let window = Int(bitPattern: budget)
        precondition(
            frontier + window <= Int(bitPattern: _capacity),
            "Storage.Contiguous.withOutputSpan(addingCapacity:): window exceeds capacity"
        )
        let start = unsafe _base + frontier
        var output = unsafe Swift.OutputSpan(
            buffer: unsafe UnsafeMutableBufferPointer(start: start, count: window),
            initializedCount: 0
        )
        defer {
            let committed = unsafe output.finalize(
                for: unsafe UnsafeMutableBufferPointer(start: start, count: window)
            )
            output = Swift.OutputSpan()
            _initialization = .linear(count: Index<Element>.Count(UInt(frontier + committed)))
        }
        return try body(&output)
    }
}

// MARK: - Span.`Protocol` / Span.Mutable.`Protocol` conformances
//
// The Storage tier conforms the span capability protocols (the W2 deferral, realized for the W3
// buffer consumer): the read `span` and the mutable `mutableSpan` properties above witness directly,
// and the count-parameterized `mutableSpan(count:)` is the seam a growable discipline
// (`Buffer.Linear`/`.Ring`) uses to vend a span bounded by its OWN header count rather than the
// storage's tracked count (a count-method forwards through a constrained generic; the property does
// not — Span.Mutable.`Protocol`'s structural gate).

extension Storage.Contiguous: Span.`Protocol` where Allocation: ~Copyable, Element: ~Copyable {}

extension Storage.Contiguous: Span.Mutable.`Protocol` where Allocation: ~Copyable, Element: ~Copyable {
    /// A mutable span over the first `count` initialized elements.
    @_lifetime(&self)
    @inlinable
    public mutating func mutableSpan(count: Index<Element>.Count) -> Swift.MutableSpan<Element> {
        let span = unsafe Swift.MutableSpan(_unsafeStart: _base, count: Int(bitPattern: count))
        return unsafe _overrideLifetime(span, mutating: &self)
    }
}

// MARK: - Capacity spans (lane-η probe — the always-full-plane door)
//
// Span access over the WHOLE capacity `[0, capacity)` WITHOUT consulting the
// initialization ledger — for plane consumers whose invariant is
// always-fully-initialized storage (ledger planes, lookup tables). The ledger
// enum read is the measured hot-path tax that pushed the Round M ledger plane
// onto raw Memory.Heap (REPORT-round-m-W1 §2b finding 1); this door offers the
// span-typed alternative at plane cost.

extension Storage.Contiguous where Allocation: ~Copyable, Element: ~Copyable {
    /// Bounds-checked read access over the WHOLE capacity, ledger-free.
    ///
    /// SAFETY: the consumer asserts every slot in `[0, capacity)` is initialized
    /// (the always-full-plane invariant); reading an uninitialized slot through
    /// the returned span is undefined behavior — that is why this door is
    /// `@unsafe` while the ledger-bounded `span` is not.
    @unsafe
    @inlinable
    public var capacitySpan: Swift.Span<Element> {
        @_lifetime(borrow self)
        get {
            let span = unsafe Swift.Span(_unsafeStart: _base, count: Int(bitPattern: _capacity))
            return unsafe _overrideLifetime(span, borrowing: self)
        }
    }

    /// Bounds-checked mutable access over the WHOLE capacity, ledger-free, under
    /// an exclusive `&self` borrow.
    ///
    /// SAFETY: see `capacitySpan` — the all-initialized invariant is the
    /// consumer's; writes through the span never change the initialization
    /// ledger (a plane stays always-full by construction).
    @unsafe
    @inlinable
    public var capacityMutableSpan: Swift.MutableSpan<Element> {
        @_lifetime(&self)
        mutating get {
            let span = unsafe Swift.MutableSpan(_unsafeStart: _base, count: Int(bitPattern: _capacity))
            return unsafe _overrideLifetime(span, mutating: &self)
        }
    }
}
