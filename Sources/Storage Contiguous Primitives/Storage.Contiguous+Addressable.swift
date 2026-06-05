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

public import Finite_Bounded_Primitives
public import Index_Primitives
public import Memory_Inline_Primitives
public import Storage_Primitive

// MARK: - Addressable leaf capability (the generalized pointer escape hatch)
//
// The dissolved `Storage.Inline` vended a typed `pointer(at:)` escape hatch the fixed-capacity
// `.Inline` buffer helpers project slots through. `Memory.Inline` (value-inline, no stable heap
// pointer to pin a same-type `Storage.Contiguous` extension on — the `n` binding wall) exposes the
// same surface; this minimal capability lets `Storage.Contiguous` forward it generically. The
// heap-backed `Storage.Contiguous<Memory.Heap>` keeps its own pinned `pointer(at:)`
// (`Storage.Heap+pointer.swift`), so the two are disjoint.

// `__MemoryAddressableProtocol` and `Memory.Inline`'s conformance live in
// swift-memory-inline-primitives (the leaf's own module), so the conformance is visible wherever
// `Memory.Inline` is imported.

extension Storage.Contiguous
where Element: ~Copyable, Substrate: __MemoryAddressableProtocol, Substrate: ~Copyable {
    /// Forwards the substrate's typed pointer escape hatch.
    @unsafe
    @inlinable
    public func pointer(at slot: Index<Element>) -> UnsafeMutablePointer<Element> {
        unsafe _substrate.pointer(at: slot)
    }

    /// Bounded-index pointer escape hatch — the fixed-capacity `.Inline` call surface.
    @unsafe
    @inlinable
    public func pointer<let capacity: Int>(
        at slot: Index<Element>.Bounded<capacity>
    ) -> UnsafeMutablePointer<Element> {
        unsafe _substrate.pointer(at: Index<Element>(slot))
    }
}

// MARK: - Sendable (the storage travels as one unit with its substrate)

extension Storage.Contiguous: @unchecked Sendable where Element: ~Copyable, Substrate: Sendable, Substrate: ~Copyable {}
