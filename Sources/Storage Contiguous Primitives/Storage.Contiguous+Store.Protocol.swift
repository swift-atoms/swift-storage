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

// The cross-module element-store seam (the typed `Store.`Protocol``, with `Index<Element>`
// preserved). The subscript witnesses via `_read` / `_modify` over the typed pointer, which
// specialize to zero `witness_method` through a concrete tower (verified on Apple Swift 6.3.2).

import Affine_Primitives_Standard_Library_Integration
public import Index_Primitives
public import Memory_Region_Primitives
import Ordinal_Primitives_Standard_Library_Integration
public import Store_Initialization_Primitives
public import Store_Protocol_Primitives

extension Storage.Contiguous where Allocation: Memory.Region & ~Copyable, Element: ~Copyable {
    /// Reads or writes the initialized element at a physical slot (witnesses `subscript(slot:)`).
    @inlinable
    public subscript(slot: Index<Element>) -> Element {
        _read {
            let pointer = unsafe _ptr(at: slot)
            yield unsafe pointer.pointee
        }
        _modify {
            let pointer = unsafe _ptr(at: slot)
            yield &(unsafe pointer.pointee)
        }
    }

    /// Initializes the uninitialized slot at `slot` (uninit → init; extends the linear-prefix ledger).
    ///
    /// The contiguous discipline appends at `slot == count`; the ledger advances by one. A composing
    /// discipline needing arbitrary-slot semantics syncs the ledger via `initialization` instead.
    @inlinable
    public mutating func initialize(at slot: Index<Element>, to element: consuming Element) {
        unsafe _ptr(at: slot).initialize(to: element)
        _initialization = .linear(count: count + .one)
    }

    /// Moves the initialized element out of `slot` (init → uninit; shrinks the linear-prefix ledger).
    @inlinable
    public mutating func move(at slot: Index<Element>) -> Element {
        let element = unsafe _ptr(at: slot).move()
        _initialization = .linear(count: count.subtract.saturating(.one))
        return element
    }
}

// MARK: - Ledger-aware removal (debug-asserted LIFO/tail removal)

// Mirrors `Store.Inline`'s ledger-aware overrides (`Store.Inline+Store.Protocol.swift`) for the
// same reason: `Store.Protocol+Deinitialize.swift`'s generic `deinitialize(at:)` /
// `deinitialize(range:)` derivations are built only on `move(at:)`, whose unconditional
// linear-prefix decrement is truthful only for tail (LIFO) removal on a currently prefix-shaped
// ledger. See the longer note in `Store.Inline+Store.Protocol.swift` for the full rationale,
// including the disclosed scope limit (generic call sites constrained to the bare
// `Store.`Protocol`` still resolve to the unguarded derivation).
extension Storage.Contiguous where Allocation: Memory.Region & ~Copyable, Element: ~Copyable {
    /// Whether removing `removed` keeps a CURRENTLY prefix-shaped ledger truthful.
    ///
    /// Always `true` when the ledger is not currently prefix-shaped (a wrapped/offset
    /// discipline owns its own resync) or when `removed` is empty.
    @inlinable
    package func _isValidPrefixTailRemoval(range removed: Swift.Range<Index<Element>>) -> Bool {
        guard initialization.isPrefixShaped, !removed.isEmpty else { return true }
        return removed.upperBound == initialization.count.map(Ordinal.init)
    }

    /// Deinitializes the element at `slot`, leaving it uninitialized.
    ///
    /// - Parameter slot: The physical slot coordinate.
    /// - Precondition: The element at `slot` must be initialized. When the ledger is currently
    ///   prefix-shaped, `slot` must additionally be its tail (debug-asserted) — the only removal
    ///   position for which `move(at:)`'s self-maintenance stays truthful.
    @inlinable
    public mutating func deinitialize(at slot: Index<Element>) {
        let removed = Swift.Range<Index<Element>>(start: slot, count: .one)
        assert(
            _isValidPrefixTailRemoval(range: removed),
            "Storage.Contiguous.deinitialize(at:): slot is not the ledger's tail — move(at:)'s "
                + "linear-prefix self-maintenance is truthful only for LIFO (tail) removal; a "
                + "non-tail removal must re-sync `initialization` explicitly "
                + "(Store.Ledgered.Protocol)"
        )
        _ = move(at: slot)
    }

    /// Deinitializes every element in `range`, leaving each slot uninitialized.
    ///
    /// - Parameter range: The contiguous range of slots to deinitialize.
    /// - Precondition: Every slot in `range` must be initialized. When the ledger is currently
    ///   prefix-shaped, `range` must additionally equal its tail range (debug-asserted); see
    ///   ``deinitialize(at:)``.
    @inlinable
    public mutating func deinitialize(range: Swift.Range<Index<Element>>) {
        assert(
            _isValidPrefixTailRemoval(range: range),
            "Storage.Contiguous.deinitialize(range:): range is not the ledger's tail range — "
                + "move(at:)'s linear-prefix self-maintenance is truthful only for LIFO (tail) "
                + "removal; a non-tail removal must re-sync `initialization` explicitly "
                + "(Store.Ledgered.Protocol)"
        )
        var slot = range.lowerBound
        while slot < range.upperBound {
            _ = move(at: slot)
            slot += .one
        }
    }
}

// MARK: - Conformance (the 4-op convenience seam — `capacity` in Storage.Contiguous.swift)

extension Storage.Contiguous: Store.`Protocol` where Allocation: Memory.Region & ~Copyable, Element: ~Copyable {}
