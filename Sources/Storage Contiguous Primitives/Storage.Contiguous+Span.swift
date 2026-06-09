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
public import Memory_Primitives_Standard_Library_Integration
public import Store_Initialization_Primitives

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
}
