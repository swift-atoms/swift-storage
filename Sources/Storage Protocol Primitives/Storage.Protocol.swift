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

public import Storage_Initialization_Primitives
public import Storage_Primitive
public import Store_Protocol_Primitives
public import Store_Tracked_Primitives

// MARK: - Storage.Protocol (Hoisted as __StorageProtocol)

/// Protocol unifying physical slot access across storage disciplines.
///
/// See ``Storage/`Protocol``` for documentation.
///
/// `__StorageProtocol` refines the tracked-store capability
/// `Store.Tracked.`Protocol`` (`__StoreTrackedProtocol`) — inheriting the four
/// element-store requirements (`capacity`, the per-slot `subscript { get set }`,
/// and the two init-state transitions `initialize(at:to:)` / `move(at:)`) from
/// `Store.`Protocol``, and the `initialization` ledger requirement from the
/// Tracked refinement — and adds the single-region slot-topology semantics
/// that distinguish single-region storage disciplines (Heap, Inline, Pool,
/// Arena) from the bare capabilities. The refinement adds no new requirements;
/// it is the marker that pins single-region slot topology onto the tracked
/// substrate. (Post-split shape: the `initialization` requirement relocated
/// one tier down into `Store.Tracked.`Protocol`` — storage-memory-split.md §1,
/// seat-ratified 2026-06-04 — so the leaf tier can carry the ledger; the
/// requirement set seen by `S: Storage.`Protocol`` consumers is IDENTICAL.)
///
/// `~Copyable` is restated on the refinement so it does not re-impose `Copyable`
/// on conformers (a bare refinement would silently require `Copyable`).
public protocol __StorageProtocol: __StoreTrackedProtocol, ~Copyable {}

// MARK: - Namespace Typealias

extension Storage where Element: ~Copyable {
    /// Protocol unifying physical slot access across `Storage` disciplines.
    ///
    /// `Storage.Protocol` (accessed as `Storage.`Protocol``) **refines** the
    /// tracked-store capability `Store.Tracked.`Protocol`` and adds single-region
    /// slot-topology semantics — it is the shared contract for single-region,
    /// slot-addressed storage disciplines (Heap, Inline, Pool, Arena). The
    /// four element-store requirements (`capacity`, the per-slot
    /// `subscript { get set }`, and the two irreducible init-state transitions
    /// `initialize(at:to:)` / `move(at:)`) are inherited from `Store.`Protocol``;
    /// the `initialization` ledger requirement is inherited from
    /// `Store.Tracked.`Protocol``; `Storage.`Protocol`` adds no new requirements,
    /// contributing only the single-region slot-topology marker. All raw-memory
    /// mechanism remains encapsulated in each conformer body. Derived lifecycle
    /// (`deinitialize` / `swapAt` / `moveInitialize`) and span access compose on
    /// top of the inherited surface per discipline.
    ///
    /// ## The ledger requirement (inherited)
    ///
    /// `initialization` — the range-tracked view that a tracked store's OWN
    /// teardown honors — now lives on `Store.Tracked.`Protocol`` (the
    /// storage/memory split relocated it so the `Memory.Heap` leaf can carry
    /// the ledger). Its semantics are unchanged, including the sanctioned
    /// `.empty` vends for stores whose teardown is NOT range-driven (per-slot
    /// bitmaps, meta/token oracles) — see `Store.Tracked.`Protocol``'s
    /// documentation and each conformer's witness.
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
