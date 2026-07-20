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
public import Store_Protocol_Primitives

// MARK: - Generic deinitialize derivations

// Written ONCE over any single-region `Storage.`Protocol`` conformer
// (`__StoreProtocol` is the hoisted name per [API-IMPL-009]). The bodies build
// only on the typed primitives `move(at:)` / `subscript` / `capacity` — never on
// `pointer(at:)` — so they survive the de-pointer phase (plan §6) unchanged. Each
// deinitialization is `move`-then-drop: moving an element out of its slot and
// discarding it deinitializes the slot for a `~Copyable` element.

extension __StoreProtocol where Self: ~Copyable {

    /// Deinitializes the element at `slot`, leaving it uninitialized.
    ///
    /// `move`-then-drop: the moved element is discarded, which runs its
    /// deinitializer (if any) and clears the slot.
    ///
    /// ## Ledger consequence — LIFO/tail-only (conformers that self-maintain a ledger)
    ///
    /// A conformer whose `move(at:)` self-maintains an initialization ledger with UNCONDITIONAL
    /// linear-prefix arithmetic (decrementing the live count by exactly one, as `Store.Inline`
    /// and `Storage.Contiguous` both do) keeps that ledger truthful ONLY when `slot` is its
    /// CURRENT tail — the LIFO discipline. Calling this generic derivation at any OTHER slot
    /// silently falsifies the ledger: the just-vacated slot re-appears as "initialized," and the
    /// real (untouched) tail slot silently drops off as "uninitialized." The conformer's own
    /// deinit oracle honors that falsified ledger, so a non-tail call here is a drop-time UB
    /// footgun (double-deinitialize of already-uninitialized memory, or a leaked live element)
    /// even though the precondition below was honestly satisfied. `Store.Inline` and
    /// `Storage.Contiguous` both expose debug-asserted, ledger-aware overrides of this same
    /// entry point (see `Store.Inline+Store.Protocol.swift` / `Storage.Contiguous+Store.Protocol.swift`)
    /// that catch a non-tail call while their ledger is currently prefix-shaped; those overrides
    /// are chosen automatically for direct calls against the concrete type, but a generic caller
    /// constrained only to this bare `__StoreProtocol` seam resolves to THIS unguarded body — a
    /// discipline that removes at a non-tail slot must re-sync `initialization` itself afterward
    /// (`Store.Ledgered.Protocol`).
    ///
    /// - Parameter slot: The physical slot coordinate.
    /// - Precondition: The element at `slot` must be initialized.
    @inlinable
    public mutating func deinitialize(at slot: Index<Element>) {
        _ = move(at: slot)
    }

    /// Deinitializes every element in `range`, leaving each slot uninitialized.
    ///
    /// Element-wise forward `move`-then-drop over the half-open range. Correct for
    /// `~Copyable` elements; the bulk path stays a concrete per-discipline
    /// capability (plan §4).
    ///
    /// See ``deinitialize(at:)`` for the same ledger-truthfulness (LIFO/tail-only) constraint —
    /// it applies per element as this walks forward, so it is honored only when `range` is
    /// exactly the ledger's current tail range.
    ///
    /// - Parameter range: The contiguous range of slots to deinitialize.
    /// - Precondition: Every slot in `range` must be initialized.
    @inlinable
    public mutating func deinitialize(range: Swift.Range<Index<Element>>) {
        var slot = range.lowerBound
        while slot < range.upperBound {
            _ = move(at: slot)
            slot += .one
        }
    }

    /// Deinitializes every element in `[0, capacity)`.
    ///
    /// - Precondition: Every slot in `[0, capacity)` must be initialized. Callers
    ///   tracking a logical count below `capacity` should prefer
    ///   `deinitialize(range:)` over the live range.
    @inlinable
    public mutating func clear() {
        let upper: Index<Element> = capacity.map(Ordinal.init)
        deinitialize(range: .zero..<upper)
    }

    /// Deinitializes every element in `[0, capacity)`.
    ///
    /// Spelling alias for ``clear()`` matching the collection-layer vocabulary.
    ///
    /// - Precondition: Every slot in `[0, capacity)` must be initialized.
    @inlinable
    public mutating func removeAll() {
        clear()
    }
}
