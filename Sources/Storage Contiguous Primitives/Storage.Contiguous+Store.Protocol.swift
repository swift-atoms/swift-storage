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
public import Memory_Tracked_Primitives
public import Storage_Initialization_Primitives
public import Storage_Primitive
public import Store_Protocol_Primitives

// MARK: - Store.Protocol Witnesses (forwarded to the substrate)

extension Storage.Contiguous where Element: ~Copyable, Substrate: ~Copyable {
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

// MARK: - The ledger forwarding (substrate-forwarding witness — the parked
// A2-addendum design, realized by the storage/memory split)

extension Storage.Contiguous where Element: ~Copyable, Substrate: Memory.Tracked.`Protocol`, Substrate: ~Copyable {
    /// The substrate's own ledger, forwarded.
    ///
    /// Available exactly when the substrate TRACKS (`Memory.Tracked.`Protocol``):
    /// the truth lives at the leaf — its backing's teardown honors what is
    /// written here. The discipline stores NO ledger of its own (and carries no
    /// `deinit` — the `bd04f32` wall is respected by construction).
    ///
    /// The former unconditional `.empty` inert witness is DELETED
    /// (storage-memory-split.md §4, seat-ratified): a Contiguous over an
    /// untracked substrate is `Store.`Protocol``-only and cannot enter
    /// `S: Storage.`Protocol`` dense disciplines, whose ledger-sync teardown
    /// contract an untracked substrate cannot honor — the silent-leak path is
    /// now unrepresentable.
    @inlinable
    public var initialization: Storage<Element>.Initialization {
        get { _substrate.initialization }
        set { _substrate.initialization = newValue }
    }
}

// MARK: - Conformance
//   Store.Protocol — unconditional (any substrate). The `initialization` ledger
//   above is a CONDITIONAL accessor (where Substrate: Memory.Tracked.`Protocol`),
//   NOT a conformance: Storage.Contiguous forwards the leaf's ledger but does not
//   itself carry the tracked-store marker (Cleave-5 D1-B — the marker narrows to
//   the leaves). The dissolved Storage.Protocol single-region marker is gone:
//   Storage.Contiguous<M> IS single-region by construction.

extension Storage.Contiguous: Store.`Protocol` where Element: ~Copyable, Substrate: ~Copyable {}
