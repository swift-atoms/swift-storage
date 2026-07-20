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

// MARK: - Generic move derivations

// Element-relocation derivations over any single-region `Storage.`Protocol``
// conformer. Built only on the typed primitives `move(at:)` / `initialize(at:to:)`
// / `subscript` — never on `pointer(at:)`. The `moveInitialize` shift is
// element-wise (correct for `~Copyable`); a bulk `BitwiseCopyable` path is
// deferred to a later benchmark (plan §2 / §10) and intentionally NOT added here.

extension __StoreProtocol where Self: ~Copyable {

    /// Exchanges the initialized elements at `i` and `j` in place.
    ///
    /// No-op when `i == j`. Count unchanged.
    ///
    /// ## Ledger consequence — why this stays truthful despite touching non-tail slots
    ///
    /// Unlike `deinitialize(at:)` (see its doc), `swapAt` never leaves a self-maintaining
    /// conformer's ledger falsified: every `move(at:)` here is immediately paired with a
    /// corresponding `initialize(at:to:)` that restores the count each decremented (two
    /// `move`s, then two `initialize`s — net count unchanged). The INTERMEDIATE ledger states
    /// between those four calls are transiently wrong (exactly like `deinitialize(at:)`'s
    /// falsification), but nothing observes the ledger mid-sequence — this is a plain,
    /// synchronous, non-throwing mutating function with no suspension point — so only the
    /// FINAL state matters, and it is correct whenever `i` and `j` were both within the
    /// ledger's live region to begin with.
    ///
    /// - Parameters:
    ///   - i: The first physical slot coordinate.
    ///   - j: The second physical slot coordinate.
    /// - Precondition: Both slots must be initialized.
    @inlinable
    public mutating func swapAt(_ i: Index<Element>, _ j: Index<Element>) {
        guard i != j else { return }
        let a = move(at: i)
        let b = move(at: j)
        initialize(at: i, to: b)
        initialize(at: j, to: a)
    }

    /// Moves the initialized element from `source` into the uninitialized slot `destination`.
    ///
    /// After the call `source` is uninitialized and `destination` is initialized.
    /// No-op when `source == destination`.
    ///
    /// Ledger-safe by the same pairing argument as ``swapAt(_:_:)``: the single `move(at:)`
    /// is immediately paired with `initialize(at:to:)`, so the net count is unchanged and the
    /// final ledger is truthful whenever both slots were already within the live region.
    ///
    /// - Parameters:
    ///   - source: The physical slot to move from (must be initialized).
    ///   - destination: The physical slot to move into (must be uninitialized).
    @inlinable
    public mutating func move(from source: Index<Element>, to destination: Index<Element>) {
        guard source != destination else { return }
        initialize(at: destination, to: move(at: source))
    }

    /// Move-initializes `count` elements from `[source, source + count)` into
    /// `[destination, destination + count)`, leaving the source slots uninitialized.
    ///
    /// Overlap-correct element-wise shift: when `destination > source` (right
    /// shift) the loop runs **backward** so an as-yet-unmoved source slot is never
    /// overwritten; otherwise (left shift / disjoint) it runs **forward**. This
    /// matches `memmove` semantics over a `~Copyable` element domain.
    ///
    /// Ledger-safe by the same pairing argument as ``swapAt(_:_:)`` / ``move(from:to:)``: each
    /// step is one `move(from:to:)` call, itself one paired `move(at:)` + `initialize(at:to:)`,
    /// so the net live count is unchanged after every step and the final ledger is truthful
    /// whenever `[source, source + count)` and `[destination, destination + count)` were
    /// already within the live region.
    ///
    /// - Parameters:
    ///   - source: The first source physical slot coordinate.
    ///   - destination: The first destination physical slot coordinate.
    ///   - count: The number of contiguous slots to relocate.
    /// - Precondition: Every source slot must be initialized; every destination
    ///   slot not already covered by the source range must be uninitialized.
    @inlinable
    public mutating func moveInitialize(
        from source: Index<Element>,
        to destination: Index<Element>,
        count: Index<Element>.Count
    ) {
        guard count > .zero, source != destination else { return }
        if destination > source {
            // Right shift (overlap-unsafe forward): relocate from the high end so an
            // as-yet-unmoved source slot is never overwritten. Each slot index is
            // rebuilt from the base plus a per-step `Offset(fromZero:)`. The
            // `Index + Offset` advance is total-throwing (it can overflow in
            // general), but the precondition — `[source, source + count)` and
            // `[destination, destination + count)` lie within `capacity` — makes
            // overflow impossible here, so the throw is absorbed with `try!`.
            var remaining: Index<Element>.Count = count
            while remaining > .zero {
                let step: Index<Element>.Count = remaining.subtract.saturating(.one)
                let offset = Index<Element>.Offset(fromZero: step.map(Ordinal.init))
                // WHY: in-capacity precondition guarantees no Ordinal overflow on this advance.
                // swift-format-ignore: NeverUseForceTry
                // swiftlint:disable:next force_try
                let sourceSlot = try! source + offset
                // WHY: in-capacity precondition guarantees no Ordinal overflow on this advance.
                // swift-format-ignore: NeverUseForceTry
                // swiftlint:disable:next force_try
                let destinationSlot = try! destination + offset
                move(from: sourceSlot, to: destinationSlot)
                remaining = step
            }
        } else {
            // Left shift / disjoint: relocate from the head, walking both cursors by
            // `+ .one` (the non-throwing successor the linear consumer uses).
            var sourceSlot = source
            var destinationSlot = destination
            var step: Index<Element>.Count = .zero
            while step < count {
                move(from: sourceSlot, to: destinationSlot)
                sourceSlot += .one
                destinationSlot += .one
                step = step.add.saturating(.one)
            }
        }
    }
}
