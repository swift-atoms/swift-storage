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

public import Store_Primitive
public import Store_Protocol_Primitives
public import Store_Initialization_Primitives

// MARK: - Store.Ledgered.Protocol (Hoisted as __StoreLedgeredProtocol)

/// An element store whose initialization ledger is settable by a composing discipline.
///
/// See ``Store/Ledgered`` for documentation.
public protocol __StoreLedgeredProtocol: Store.`Protocol`, ~Copyable {
    /// The initialization ledger — settable so a composing discipline whose occupancy is
    /// NOT prefix-shaped can bulk-sync it after its own cursor arithmetic.
    ///
    /// The seam's own `initialize(at:to:)` / `move(at:)` self-maintain the ledger with
    /// unconditional PREFIX arithmetic (the linear-family contract). A discipline that
    /// writes at wrapped or sparse physical slots (the ring now; future wrapped/sparse
    /// disciplines) makes the self-maintained ledger untruthful and MUST overwrite it
    /// with its own computed shape after every seam op — the explicit-sync route the
    /// seam's documentation has always reserved for arbitrary-slot disciplines. The
    /// conformer's deinit oracle honors whatever is written here.
    var initialization: Store.Initialization<Element> { get set }
}

// MARK: - Namespace

extension Store {
    /// The ledgered element-store capability.
    ///
    /// `Store.Ledgered.`Protocol`` is the SIBLING refinement beside the 4+1-op seam
    /// (`Store.`Protocol`` itself is unchanged): it adds exactly one requirement — the
    /// settable `initialization` ledger — so that a composing discipline whose occupancy
    /// is not prefix-shaped can keep the leaf's deinit oracle truthful.
    ///
    /// ## Why a refinement, not a seam change
    ///
    /// The 4-op seam's ledger self-maintenance is linear-prefix-shaped. A wrapped
    /// discipline (`Buffer.Ring`) writes at physical slots the prefix rule cannot
    /// describe; without the sync, the leaf's deinit oracle would destroy the wrong
    /// slots on drop. Both leaf stores already expose the capability publicly
    /// (`Storage.Contiguous.initialization { get set }`,
    /// `Store.Inline.initialization { get set }` — each documented "settable so a
    /// composing discipline can bulk-sync it"); this protocol merely NAMES it so the
    /// composition can be generic. Ratified 2026-06-10 (ASK-A,
    /// `REPORT-ADT-families-spike-findings.md` F-1).
    ///
    /// ## Hoisted Protocol Pattern
    ///
    /// Declared at module scope as `__StoreLedgeredProtocol` and aliased into the
    /// namespace per the `Store.`Protocol`` precedent ([PKG-NAME-006]).
    public enum Ledgered {}
}

extension Store.Ledgered {
    /// The ledgered element-store capability contract.
    public typealias `Protocol` = __StoreLedgeredProtocol
}
