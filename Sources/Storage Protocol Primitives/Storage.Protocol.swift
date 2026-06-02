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
public import Storage_Primitive

// MARK: - Storage.Protocol (Hoisted as __StorageProtocol)

/// Protocol unifying physical slot access across storage disciplines.
///
/// See ``Storage/`Protocol``` for documentation.
public protocol __StorageProtocol: ~Copyable {
    /// The element type stored in each physical slot.
    associatedtype Element: ~Copyable

    /// The total number of physical slots this storage provides.
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
    ///   - element: The value to store; ownership transfers to the storage.
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
}

// MARK: - Namespace Typealias

extension Storage where Element: ~Copyable {
    /// Protocol unifying physical slot access across `Storage` disciplines.
    ///
    /// `Storage.Protocol` (accessed as `Storage.`Protocol``) is the shared
    /// contract for single-region, slot-addressed storage disciplines (Heap,
    /// Inline, Pool, Arena, Slab). It exposes a fully-typed, pointer-free slot
    /// surface — `capacity`, the per-slot `subscript { get set }`, and the two
    /// irreducible init-state transitions `initialize(at:to:)` / `move(at:)`,
    /// with all raw-memory mechanism encapsulated in each conformer body.
    /// Derived lifecycle (`deinitialize` / `swapAt` / `moveInitialize`) and span
    /// access compose on top of these per discipline.
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
    /// `Storage.Split` is multi-region — its access primitive is
    /// `pointer(_:at:)` over a `Storage.Field` handle — and therefore does not
    /// conform to this single-region contract.
    public typealias `Protocol` = __StorageProtocol
}
