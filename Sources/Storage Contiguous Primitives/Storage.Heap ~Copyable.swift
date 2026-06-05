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
public import Memory_Heap_Primitives
public import Storage_Initialization_Primitives
public import Storage_Primitive

// MARK: - Pinned heap-composition surface (~Copyable)
//
// The fused Storage.Contiguous<Memory.Heap<Element>>'s concrete surface, re-homed as pinned forwarders on
// the composed type. `capacity`, the element seam, and `initialization` come
// GENERICALLY from Storage.Contiguous (+ the Tracked-conditional witness);
// only the leaf-concrete members need the pin.

extension Storage.Contiguous where Element: ~Copyable, Substrate == Memory.Heap<Element> {
    /// Creates heap storage with the specified minimum capacity.
    ///
    /// The pinned factory: allocates the leaf (one heap allocation) and lifts
    /// it into the discipline.
    ///
    /// - Parameter minimumCapacity: The minimum number of slots to allocate.
    /// - Returns: A new storage instance with empty initialization.
    @inlinable
    public static func create(
        minimumCapacity: Index<Element>.Count
    ) -> Self {
        Self(Memory.Heap.create(minimumCapacity: minimumCapacity))
    }

    /// Whether no slots are initialized.
    @inlinable
    public var isEmpty: Bool {
        _substrate.isEmpty
    }
}

extension Storage.Contiguous where Element: ~Copyable, Substrate == Memory.Heap<Element> {
    /// The initialization ledger — pinned NONMUTATING shadow for the heap
    /// composition.
    ///
    /// The fused `Storage.Contiguous<Memory.Heap<Element>>`'s setter was `nonmutating` (it writes through
    /// the backing class reference), so `let`-bound storages could arm the
    /// ledger. The generic Tracked-conditional witness must be `mutating`
    /// (a generic substrate's setter is); this more-constrained shadow
    /// restores the fused type's mutability posture at every concrete
    /// `Storage<E>.Contiguous<Memory.Heap<E>>` site — overload resolution prefers it — while the
    /// generic witness continues to serve `S: Storage.`Protocol`` contexts
    /// (where the leaf's own nonmutating setter makes the mutating call
    /// equally sound).
    @inlinable
    public var initialization: Storage<Element>.Initialization {
        get { _substrate.initialization }
        nonmutating set { _substrate.initialization = newValue }
    }
}
