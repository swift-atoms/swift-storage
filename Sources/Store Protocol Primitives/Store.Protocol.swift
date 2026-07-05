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
public import Store_Primitive

// MARK: - Store.Protocol (Hoisted as __StoreProtocol)

/// The neutral element-store capability.
///
/// See ``Store/`Protocol``` for documentation.
public protocol __StoreProtocol: ~Copyable {
    /// The element type stored in each physical slot.
    associatedtype Element: ~Copyable

    /// The total number of physical slots this store provides.
    var capacity: Index<Element>.Count { get }

    /// Reads or writes the **initialized** element at the given physical slot.
    ///
    /// The per-slot typed primitive. Both ends are by-value over a `~Copyable`
    /// element, so the witness supplies coroutine accessors (`_read` yields a
    /// borrow; `_modify` yields an exclusive mutable view). The requirement is
    /// spelled `{ get set }` — the `{ read modify }` spelling does not parse as a
    /// protocol property requirement on Apple Swift 6.3.2 — and conformers
    /// witness it with `_read` / `_modify`.
    ///
    /// This subscript is the heart of the generic cross-module mutate seam: a
    /// generic function constrained to `Store.`Protocol`` can read and write the
    /// elements of a concrete conformer declared in another module, and the
    /// optimizer specializes the `_read` / `_modify` coroutine witnesses to direct
    /// calls — zero `witness_method` cross-module dispatch — even through a
    /// multi-deep generic tower (verified on Apple Swift 6.3.2).
    ///
    /// - Parameter slot: The physical slot coordinate.
    /// - Returns: The element at the slot.
    /// - Precondition: The element at `slot` must be initialized and within capacity.
    subscript(slot: Index<Element>) -> Element { get set }

    /// Initializes the **uninitialized** element at `slot` to `element`.
    ///
    /// One of the two irreducible init-state transitions (`uninit → init`). Any
    /// raw-memory mechanism is encapsulated in the conformer body; the protocol
    /// surface is typed and pointer-free.
    ///
    /// - Parameters:
    ///   - slot: The physical slot coordinate.
    ///   - element: The value to store; ownership transfers to the store.
    /// - Precondition: The element at `slot` must be uninitialized and within capacity.
    mutating func initialize(at slot: Index<Element>, to element: consuming Element)

    /// Moves the **initialized** element out of `slot`, leaving it uninitialized.
    ///
    /// The second irreducible init-state transition (`init → uninit`). Any
    /// raw-memory mechanism is encapsulated in the conformer body.
    ///
    /// - Parameter slot: The physical slot coordinate.
    /// - Returns: The moved element; ownership transfers to the caller.
    /// - Precondition: The element at `slot` must be initialized and within capacity.
    mutating func move(at slot: Index<Element>) -> Element

    /// The semantic mutation gate (W4 amendment; defaulted).
    ///
    /// Generic code MUST call this before its first write through the seam in any
    /// semantic mutation (subscript `_modify`, removal, in-place edit). Plain stores
    /// are statically unique and inherit the no-op default; reference-shared CoW
    /// columns (`Shared`) override it to restore uniqueness — the stdlib
    /// `_makeUniqueAndReserveCapacityIfNotUnique()` shape, hoisted to the seam so the
    /// ADT tier's generic witnesses stay copy-on-write-correct without per-column pins.
    ///
    /// The seam's other operations remain the documented unchecked fast lane: a caller
    /// that has already gated (or is statically unique) may batch through them freely.
    mutating func unshare()
}

// MARK: - Default (statically-unique stores)

extension __StoreProtocol where Self: ~Copyable {
    /// Plain stores have no shared backing to restore; the gate is a no-op.
    @inlinable
    public mutating func unshare() {}
}

// MARK: - Namespace Typealias

extension Store {
    /// The neutral element-store capability contract.
    ///
    /// `Store.Protocol` (accessed as `Store.`Protocol``) is the substrate-level
    /// contract for reading, writing, initializing, and moving a single typed
    /// element at a physical slot. It exposes a fully-typed, pointer-free slot
    /// surface — `capacity`, the per-slot `subscript { get set }`, and the two
    /// irreducible init-state transitions `initialize(at:to:)` / `move(at:)`, with
    /// all raw-memory mechanism encapsulated in each conformer body.
    ///
    /// ## The generic cross-module mutate seam
    ///
    /// These four requirements — plus the defaulted `unshare()` gate —
    /// are the **generic cross-module mutate seam**: the
    /// minimal set through which a generic function in one module can mutate a
    /// concrete element-addressed container declared in another module, with the
    /// `_read` / `_modify` subscript witnesses specializing to zero
    /// `witness_method` cross-module dispatch through a multi-deep generic tower
    /// (verified on Apple Swift 6.3.2). The capability is deliberately lifted out
    /// of any storage discipline or memory representation so that the seam lives in
    /// a neutral substrate that every element-addressed type can adopt.
    ///
    /// ## Convenience, not foundational (R2)
    ///
    /// `Store.`Protocol`` is a **deletable convenience code-share vehicle**, not a
    /// foundational layer. A protocol extension *is* a generic constraint, so the
    /// real axis is *load-bearing vs deletable*, not protocol-vs-concrete. The
    /// five-layer tower composes over **concrete** nested storage types
    /// (`Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Element>`); this
    /// seam exists only to share generic algorithms across them, and the cross-module
    /// `_read` / `_modify` subscript witnesses specialize to zero `witness_method`
    /// dispatch through a multi-deep concrete tower either way (verified on Apple
    /// Swift 6.3.2 — choosing the seam vs a concrete `where ==` pin is a code-share
    /// decision, not a performance one).
    ///
    /// The seam is therefore **never refined into storage identity**: there is no
    /// foundational `Storage.`Protocol`` refining it. The earlier
    /// `Store.Protocol ⊂ Storage.Protocol` chain is **withdrawn** — it was never
    /// built (`Store.Tracked.Protocol` was eliminated 2026-06-05; `Storage.Protocol`
    /// never materialized). Conformers (`Storage.Contiguous`, `Storage.Generational`,
    /// …) adopt these four requirements directly; derived lifecycle and span access
    /// compose on top per discipline.
    ///
    /// ## Hoisted Protocol Pattern
    ///
    /// Swift does not allow nesting a protocol inside a generic type, and — for
    /// uniformity with the sibling `Storage.`Protocol`` substrate, whose namespace
    /// *is* generic — `Store.`Protocol`` follows the same hoisted-protocol idiom
    /// ([PKG-NAME-006]). The protocol is declared at module scope as
    /// `__StoreProtocol` and aliased into the namespace:
    ///
    /// ```swift
    /// extension Store {
    ///     public typealias `Protocol` = __StoreProtocol
    /// }
    /// ```
    ///
    /// `associatedtype Element: ~Copyable` relies on the `SuppressedAssociatedTypes`
    /// experimental feature.
    public typealias `Protocol` = __StoreProtocol
}
