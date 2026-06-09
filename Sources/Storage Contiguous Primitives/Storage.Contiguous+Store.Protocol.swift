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

public import Index_Primitives
public import Store_Protocol_Primitives
public import Store_Initialization_Primitives
import Affine_Primitives_Standard_Library_Integration
import Ordinal_Primitives_Standard_Library_Integration

extension Storage.Contiguous where Allocation: ~Copyable, Element: ~Copyable {
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

// MARK: - Conformance (the 4-op convenience seam — `capacity` in Storage.Contiguous.swift)

extension Storage.Contiguous: Store.`Protocol` where Allocation: ~Copyable, Element: ~Copyable {}
