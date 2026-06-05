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
public import Store_Creatable_Primitives
public import Store_Protocol_Primitives

// MARK: - Default relocation for creatable stores (element-wise over the neutral seam)

extension __StoreCreatableProtocol where Self: ~Copyable {

    /// Element-wise relocation of the initialized prefix `[0, count)` from `self`
    /// into `destination`, built only on the neutral seam primitives `move(at:)`
    /// and `initialize(at:to:)`. Correct for `~Copyable` elements and available to
    /// every creatable store; single-region contiguous stores override with a bulk
    /// path (`Storage.Contiguous` — `Storage.Contiguous+Store.Creatable.Protocol.swift`).
    ///
    /// The ledger (`Store.Tracked`) is synced by the caller, not here — matching the
    /// pre-generalization growth contract.
    @inlinable
    public mutating func moveInitializePrefix(count: Index<Element>.Count, into destination: inout Self) {
        var slot: Index<Element> = .zero
        var moved: Index<Element>.Count = .zero
        while moved < count {
            destination.initialize(at: slot, to: move(at: slot))
            slot += .one
            moved = moved.add.saturating(.one)
        }
    }
}
