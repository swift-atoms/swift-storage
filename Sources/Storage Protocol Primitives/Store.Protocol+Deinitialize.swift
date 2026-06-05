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
