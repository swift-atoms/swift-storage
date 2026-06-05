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
public import Store_Creatable_Primitives

// MARK: - Store.Creatable.Protocol conformance (generic — any creatable leaf)
//
// The discipline-side creatable conformance for `Storage.Contiguous` over ANY creatable leaf
// (e.g. `Memory.Small`): `create` delegates the sized-allocation DECISION to the leaf; the
// relocation forwards through the leaf's neutral-seam relocation — the discipline owns the MOVE
// (it has the count; it forwards with it). The heap-backed `Storage.Contiguous<Memory.Heap>` keeps
// its specialized bulk conformance (`Storage.Contiguous+Store.Creatable.Protocol.swift`);
// `Memory.Heap` itself is not `Store.Creatable`, so the two conformances are disjoint.

extension Storage.Contiguous: Store.Creatable.`Protocol`
where Element: ~Copyable, Substrate: Store.Creatable.`Protocol`, Substrate: ~Copyable {

    /// Allocates a `Storage.Contiguous` sized for at least `minimumCapacity` by delegating the
    /// allocation DECISION to the substrate leaf, then lifting it into the contiguous discipline.
    @inlinable
    public static func create(minimumCapacity: Index<Element>.Count) -> Self {
        Self(Substrate.create(minimumCapacity: minimumCapacity))
    }

    /// Relocates the initialized prefix `[0, count)` into `destination` by forwarding through the
    /// substrate's relocation (element-wise for a hybrid leaf such as `Memory.Small`).
    @inlinable
    public mutating func moveInitializePrefix(count: Index<Element>.Count, into destination: inout Self) {
        _substrate.moveInitializePrefix(count: count, into: &destination._substrate)
    }

    /// Wrap-around relocation, forwarded to the substrate (linearizes a wrapped ring on grow).
    @inlinable
    public mutating func moveInitialize(
        range: Swift.Range<Index<Element>>,
        into destination: inout Self,
        at destinationOffset: Index<Element>
    ) {
        _substrate.moveInitialize(range: range, into: &destination._substrate, at: destinationOffset)
    }
}
