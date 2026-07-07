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

// MARK: - Column.Direct (Hoisted as __ColumnDirect)

/// The DIRECT-column capability marker — the axis-changing-alias fence ([DS-028] law 1).
///
/// See ``Column/Direct`` for the consumer-facing documentation (the namespace alias is
/// declared in the column-vocabulary module).
///
/// A **direct canonical column** — a buffer-discipline stack (`Buffer.Linear`, `Buffer.Ring`)
/// or a storage-direct column — conforms to this marker. `Shared` and bounded instantiations
/// do **NOT** conform (that absence IS the fence): an axis-CHANGING front-door alias
/// (allocation, for example `Array<E>.Small<n>`) constrains its column to `Column.Direct`, so a
/// cross-axis chain that would silently reset an already-set axis (`Shared`, bounded) fails
/// to compile rather than dropping the axis without a diagnostic.
///
/// It refines ``Store/`Protocol``` so `Element` is available in the axis-changing alias
/// bodies with a single constraint, and it carries the capacity-twin column ``Bounded`` — the
/// column-PRESERVING `.Bounded` front-door alias maps through it (`__X<S.Bounded>`,
/// [DS-028] law 2), so it composes order-insensitively with the other axes.
///
/// A deletable convenience per [API-IMPL-023]; homed at the `Store.`Protocol`` seam tier —
/// the tier both buffer disciplines and storage-direct columns can reach.
@_documentation(visibility: public)
public protocol __ColumnDirect: __StoreProtocol, ~Copyable {
    /// The bounded (fixed-capacity) capacity-twin column for this direct column.
    ///
    /// The column-preserving `.Bounded` front-door alias maps through this ([DS-028] law 2):
    /// `Buffer.Linear` and `Buffer.Ring` witness it by member-name inference with their own
    /// nested `.Bounded` type. Every §5.1 product point — including the live `Shared×Bounded`
    /// ring column — therefore has one correct, order-insensitive spelling.
    associatedtype Bounded: ~Copyable
}

// MARK: - Namespace Typealias

extension Store {
    /// The seam-tier spelling of the DIRECT-column fence marker ([API-NAME-004], M4).
    ///
    /// `Store.Direct` vends the hoisted ``__ColumnDirect`` marker at the `Store.`Protocol``
    /// seam tier — the tier both buffer disciplines and storage-direct columns can reach — so
    /// that in-tower conformances and where-clauses bind `Store.Direct` rather than the
    /// `__`-prefixed marker directly. No dunder token therefore ever appears in a public
    /// conformance clause. It is DISTINCT from the consumer-facing ``Column/Direct`` vocabulary
    /// spelling (declared in the column-vocabulary module): both alias the same marker, but
    /// `Store.Direct` is the seam-tier binding the tower's own carriers use.
    ///
    /// This follows the same hoisted-protocol idiom as `Store.`Protocol`` ([PKG-NAME-006]).
    /// The `Direct` marker is **load-bearing**, NOT a deletable convenience ([API-IMPL-023],
    /// M4): it is the axis-drop fence the [DS-028] front-door alias laws depend on.
    public typealias Direct = __ColumnDirect
}
