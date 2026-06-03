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

// MARK: - Generic fill derivations

// Built only on the typed primitives `initialize(at:to:)` / `capacity`. Filling
// replicates a value into uninitialized slots, so it requires `Element: Copyable`
// (a `~Copyable` element cannot be copied into multiple slots).

extension __StorageProtocol where Self: ~Copyable, Element: Copyable {

    /// Initializes every slot in `range` to a copy of `element`.
    ///
    /// - Parameters:
    ///   - range: The contiguous range of slots to fill.
    ///   - element: The value to copy into each slot.
    /// - Precondition: Every slot in `range` must be uninitialized and within capacity.
    @inlinable
    public mutating func fill(range: Swift.Range<Index<Element>>, with element: Element) {
        var slot = range.lowerBound
        while slot < range.upperBound {
            initialize(at: slot, to: element)
            slot += .one
        }
    }

    /// Initializes every slot in `[0, capacity)` to a copy of `element`.
    ///
    /// - Parameter element: The value to copy into each slot.
    /// - Precondition: Every slot in `[0, capacity)` must be uninitialized.
    @inlinable
    public mutating func fill(with element: Element) {
        let upper: Index<Element> = capacity.map(Ordinal.init)
        fill(range: .zero..<upper, with: element)
    }
}
