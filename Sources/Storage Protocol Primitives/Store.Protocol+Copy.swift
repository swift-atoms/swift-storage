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

// MARK: - Generic copy derivation

// Copies initialized elements from one conformer into another. Copying replicates
// values, so the element must be `Copyable`; the source is borrowed (its slots
// stay initialized) and read via the `subscript` getter, the destination's slots
// are filled via `initialize(at:to:)`. Built only on the typed primitives.

extension __StoreProtocol where Self: ~Copyable, Element: Copyable {

    // reason: `Destination: __StoreProtocol` is a generic-parameter CONSTRAINT —
    // `Self` here would demand identity (Destination == Self), not conformance,
    // changing the semantics (P1a sequence/comparison precedent).
    // swiftlint:disable prefer_self_in_static_references
    /// Copies the elements in `[0, count)` of `self` into the same slots of `destination`.
    ///
    /// The source is left unchanged. `count` defaults to `self.capacity`; pass a
    /// smaller live count when only a prefix is initialized.
    ///
    /// - Parameters:
    ///   - destination: The conformer to copy into (same `Element` type).
    ///   - count: The number of leading slots to copy. Defaults to `capacity`.
    /// - Precondition: Slots `[0, count)` of `self` are initialized and within
    ///   capacity; the corresponding slots of `destination` are uninitialized and
    ///   within `destination.capacity`.
    @inlinable
    public func copy<Destination: __StoreProtocol & ~Copyable>(
        to destination: inout Destination,
        count: Index<Element>.Count? = nil
    ) where Destination.Element == Element {
        // swiftlint:enable prefer_self_in_static_references
        let limit: Index<Element>.Count = count ?? capacity
        var slot: Index<Element> = .zero
        let upper: Index<Element> = limit.map(Ordinal.init)
        while slot < upper {
            destination.initialize(at: slot, to: self[slot])
            slot += .one
        }
    }
}
