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
public import Memory_Allocatable_Primitives
public import Storage_Primitive

// MARK: - Memory.Allocatable forwarding (conditional — where the substrate allocates)
//
// `Storage.Contiguous` forwards sized-allocation and relocation to its substrate leaf when the
// leaf is `Memory.Allocatable.`Protocol`` (Memory.Heap bulk, Memory.Small element-wise — each
// witnessed statically by the concrete leaf, no override). These are CONDITIONAL forwarding
// methods, NOT a conformance: the buffer disciplines reach them via
// `where S == Storage.Contiguous<M>, M: Memory.Allocatable.`Protocol``. The discipline owns the
// MOVE (it has the count); the leaf's ledger is synced by the caller.

extension Storage.Contiguous
where Element: ~Copyable, Substrate: Memory.Allocatable.`Protocol`, Substrate: ~Copyable {

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
