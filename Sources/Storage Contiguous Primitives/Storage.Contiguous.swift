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

extension Storage where Element: ~Copyable {
    /// Contiguous storage lifting an element-store substrate into the Storage tier.
    ///
    /// `Storage.Contiguous` is the trivial single-plane storage of the substitution
    /// tower: it composes ONE element-store substrate (`Store.`Protocol``) and
    /// forwards the four element-store operations to it unchanged. Its value is
    /// positional — it lifts any substrate (a Memory-tier typed lens such as
    /// `Memory.Contiguous`, or another store) into a `Storage.`Protocol``
    /// conformer that the Buffer tier composes generically, without the
    /// substrate having to know the Storage tier exists.
    ///
    /// ## Substitution tower position
    ///
    /// ```
    /// Buffer.Ring<S>               (occupancy discipline)
    ///     └─ S = Storage.Contiguous<M>   (typed slots, single contiguous plane)
    ///            └─ M              (owned region: Memory-tier typed lens)
    /// ```
    ///
    /// The generic cross-module mutate seam is element-level
    /// (`Store.`Protocol``, CLCPM §12) — never `MutableSpan`, which cannot
    /// cross a generic module boundary.
    ///
    /// ## Ownership
    ///
    /// `Storage.Contiguous` owns its substrate (`consuming` at init); the substrate's
    /// own `deinit` releases the underlying region. Element lifecycle remains
    /// the consumer's responsibility, exactly as on the substrate itself.
    ///
    /// - SeeAlso: ``Storage/Split``, the dual-plane (lane + element) sibling.
    public struct Contiguous<Substrate: Store.`Protocol` & ~Copyable>: ~Copyable
    where Substrate.Element == Element {
        /// The composed element-store substrate.
        @usableFromInline
        internal var _substrate: Substrate

        /// Creates flat storage over the given substrate.
        ///
        /// - Parameter substrate: The element store providing the slots;
        ///   ownership transfers to the flat storage.
        @inlinable
        public init(_ substrate: consuming Substrate) {
            self._substrate = substrate
        }
    }
}

// MARK: - Conditional Copyable (NEW — the storage/memory split)

/// `Storage.Contiguous` is `Copyable` exactly when its substrate is — so the
/// composed `Storage<E>.Contiguous<Memory.Heap<E>>` (= `Contiguous<Memory.Heap<E>>`) keeps the fused
/// type's `Copyable where Element: Copyable` law through the leaf's own
/// conditional Copyability. Same-file per [COPY-FIX-004]. No `deinit` anywhere
/// on this type — conditionally-Copyable generic structs cannot carry one (the
/// `bd04f32` wall); cleanup belongs to the leaf's class.
extension Storage.Contiguous: Copyable where Element: ~Copyable, Substrate: Copyable {}
