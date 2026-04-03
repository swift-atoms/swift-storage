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

public import Storage_Primitives_Core
public import Bit_Vector_Bounded_Primitives

// MARK: - Factory

extension Storage.Slab where Element: ~Copyable {
    /// Creates slab storage with at least the specified element capacity.
    ///
    /// Allocates a `Storage<Element>.Heap` and initializes a bitmap
    /// with all slots vacant.
    ///
    /// - Parameter minimumCapacity: Number of element slots.
    @inlinable
    public convenience init(minimumCapacity: Index<Element>.Count) {
        let heap = Storage<Element>.Heap.create(minimumCapacity: minimumCapacity)
        let bitmap = try! Bit.Vector.Bounded(
            capacity: heap.slotCapacity.retag(Bit.self),
            count: heap.slotCapacity.retag(Bit.self)
        )
        self.init(_heap: heap, bitmap: bitmap)
    }
}

// MARK: - Properties

extension Storage.Slab where Element: ~Copyable {
    /// Total number of element slots.
    @inlinable
    public var slotCapacity: Index<Element>.Count { _heap.slotCapacity }

    /// The underlying heap storage.
    ///
    /// Exposed for buffer-layer consumers that need to pass `Storage<Element>.Heap`
    /// to static operations (e.g., `Buffer.Slab.insert`, `Buffer.Slab.remove`).
    @inlinable
    public var heap: Storage<Element>.Heap { _heap }

    /// Bitmap tracking which slots are occupied.
    ///
    /// Write-through synced from the owning Buffer.Slab's header.
    @inlinable
    public var bitmap: Bit.Vector.Bounded {
        get { _bitmap }
        set { _bitmap = newValue }
    }

    /// Returns a mutable pointer to the element at the given slot index.
    @unsafe
    @inlinable
    public func pointer(at slot: Index<Element>) -> UnsafeMutablePointer<Element> {
        unsafe _heap.pointer(at: slot)
    }
}

// MARK: - Sendable

extension Storage.Slab: @unchecked Sendable where Element: Sendable {}
