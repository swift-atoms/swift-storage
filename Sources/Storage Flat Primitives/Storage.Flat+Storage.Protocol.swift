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

public import Index_Primitives
public import Storage_Initialization_Primitives
public import Storage_Primitive
public import Storage_Protocol_Primitives
public import Store_Protocol_Primitives

// MARK: - Storage.Protocol Witnesses (forwarded to the substrate)

extension Storage.Flat where Element: ~Copyable, Substrate: ~Copyable {
    /// Total slot capacity — the substrate's capacity, unchanged.
    @inlinable
    public var capacity: Index<Element>.Count {
        _substrate.capacity
    }

    /// Reads or writes the initialized element at the given physical slot.
    ///
    /// Witnesses the `subscript(slot:)` requirement of `Storage.`Protocol`` by
    /// yielding through the substrate's own `_read`/`_modify` accessors — the
    /// element-store seam crossing that specializes to zero `witness_method`
    /// on concrete towers (CLCPM §3.3).
    ///
    /// - Parameter slot: The physical slot coordinate.
    /// - Precondition: The element at `slot` must be initialized and within capacity.
    @inlinable
    public subscript(slot: Index<Element>) -> Element {
        _read { yield _substrate[slot] }
        _modify { yield &_substrate[slot] }
    }

    /// Initializes the uninitialized slot at `slot` to `element`.
    ///
    /// Witnesses the `initialize(at:to:)` requirement of `Storage.`Protocol``;
    /// forwards to the substrate.
    ///
    /// - Parameters:
    ///   - slot: The physical slot coordinate.
    ///   - element: The value to store; ownership transfers to the substrate.
    /// - Precondition: The element at `slot` must be uninitialized and within capacity.
    @inlinable
    public mutating func initialize(at slot: Index<Element>, to element: consuming Element) {
        _substrate.initialize(at: slot, to: element)
    }

    /// Moves the initialized element out of `slot`, leaving it uninitialized.
    ///
    /// Witnesses the `move(at:)` requirement of `Storage.`Protocol``; forwards
    /// to the substrate.
    ///
    /// - Parameter slot: The physical slot coordinate.
    /// - Returns: The moved element; ownership transfers to the caller.
    /// - Precondition: The element at `slot` must be initialized and within capacity.
    @inlinable
    public mutating func move(at slot: Index<Element>) -> Element {
        _substrate.move(at: slot)
    }
}

// MARK: - Storage.Protocol `initialization` Witness (ASK-1 (b′) lift)

extension Storage.Flat where Element: ~Copyable, Substrate: ~Copyable {
    /// EXPLICIT `.empty` SEMANTICS (the supervisor-sanctioned shape for a
    /// Flat over an UNTRACKED substrate): the composed `Store.`Protocol``
    /// substrate carries no initialization tracking and Flat itself arms no
    /// teardown (conditionally Copyable ⇒ no deinit).
    ///
    /// Reads vend `.empty`; sets do not arm cleanup. Disciplines over Flat
    /// own their occupancy (exactly the Buffer-tier contract).
    @inlinable
    public var initialization: Storage<Element>.Initialization {
        get { .empty }
        set {}
    }
}

// MARK: - Storage.Protocol Conformance

extension Storage.Flat: Storage.`Protocol` where Element: ~Copyable, Substrate: ~Copyable {}
