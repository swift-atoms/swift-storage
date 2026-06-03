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

public import Storage_Primitive
public import Storage_Initialization_Primitives
public import Store_Protocol_Primitives

// MARK: - Storage.Protocol (Hoisted as __StorageProtocol)

/// Protocol unifying physical slot access across storage disciplines.
///
/// See ``Storage/`Protocol``` for documentation.
///
/// `__StorageProtocol` refines the neutral element-store substrate
/// `Store.`Protocol`` (`__StoreProtocol`) — inheriting its four element-store
/// requirements (`capacity`, the per-slot `subscript { get set }`, and the two
/// init-state transitions `initialize(at:to:)` / `move(at:)`) — and adds the
/// single-region slot-topology semantics that distinguish single-region storage
/// disciplines (Heap, Inline, Pool, Arena, Slab) from the bare element-store
/// capability. The refinement adds no new requirements; it is the marker that
/// pins single-region slot topology onto the neutral substrate.
///
/// `~Copyable` is restated on the refinement so it does not re-impose `Copyable`
/// on conformers (a bare `: __StoreProtocol` refinement would silently require
/// `Copyable`).
public protocol __StorageProtocol: __StoreProtocol, ~Copyable {
    /// The range-tracked initialization view that the store's OWN teardown
    /// honors — the converged "uninit↔init transitions" slot-topology content
    /// (ASK-1 (b′) lift, supervisor-approved 2026-06-04).
    ///
    /// Disciplines that delegate cleanup to their storage (Ring/Linear over a
    /// tracked substrate) SYNC this before release; stores whose teardown is
    /// NOT range-driven (per-slot bitmaps, meta/token oracles, untracked
    /// substrates) vend an explicit `.empty` and document that sets do not
    /// arm their teardown — see each conformer's witness.
    var initialization: Storage<Element>.Initialization { get set }
}

// MARK: - Namespace Typealias

extension Storage where Element: ~Copyable {
    /// Protocol unifying physical slot access across `Storage` disciplines.
    ///
    /// `Storage.Protocol` (accessed as `Storage.`Protocol``) **refines** the
    /// neutral element-store substrate `Store.`Protocol`` and adds single-region
    /// slot-topology semantics — it is the shared contract for single-region,
    /// slot-addressed storage disciplines (Heap, Inline, Pool, Arena, Slab). The
    /// four element-store requirements (`capacity`, the per-slot
    /// `subscript { get set }`, and the two irreducible init-state transitions
    /// `initialize(at:to:)` / `move(at:)`) are **inherited from `Store.`Protocol``**;
    /// `Storage.`Protocol`` adds no new requirements, contributing only the
    /// single-region slot-topology marker on top of the neutral substrate. All
    /// raw-memory mechanism remains encapsulated in each conformer body. Derived
    /// lifecycle (`deinitialize` / `swapAt` / `moveInitialize`) and span access
    /// compose on top of the inherited element-store surface per discipline.
    ///
    /// ## Hoisted Protocol Pattern
    ///
    /// Swift does not allow nesting a protocol inside a generic type, so the
    /// protocol is declared at module scope as `__StorageProtocol` and aliased
    /// into the namespace:
    ///
    /// ```swift
    /// extension Storage {
    ///     public typealias `Protocol` = __StorageProtocol
    /// }
    /// ```
    ///
    /// `associatedtype Element: ~Copyable` relies on the `SuppressedAssociatedTypes`
    /// experimental feature.
    ///
    /// ## Multi-region disciplines
    ///
    /// `Storage.Split` is dual-plane; it conforms over its PAYLOAD plane
    /// (W3 — `initialization` forwards the payload plane's, available when
    /// the plane is itself a `Storage.`Protocol`` conformer).
    public typealias `Protocol` = __StorageProtocol
}
