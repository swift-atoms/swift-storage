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
public import Bit_Vector_Primitives
internal import Property_Primitives

// MARK: - Properties

extension Storage.Arena where Element: ~Copyable {
    /// Total number of element slots.
    @inlinable
    public var capacity: Index<Element>.Count { _capacity }

    /// Number of currently allocated (initialized) slots.
    @inlinable
    public var allocated: Index<Element>.Count { _allocated }

    /// Number of remaining (unallocated) slots.
    @inlinable
    public var remaining: Index<Element>.Count {
        _capacity.subtract.saturating(_allocated)
    }

    /// Whether no slots are allocated.
    @inlinable
    public var isEmpty: Bool { _allocated == .zero }
}

// MARK: - Operations

extension Storage.Arena where Element: ~Copyable {
    /// Allocates the next slot and returns its index.
    ///
    /// The returned slot contains uninitialized memory — the caller must
    /// initialize it before use.
    ///
    /// - Returns: Index of the allocated slot, or `nil` if the arena is full.
    /// - Complexity: O(1)
    @inlinable
    public func allocate() -> Index<Element>? {
        let alignment = try! Memory.Alignment(MemoryLayout<Element>.alignment)
        let byteCount = Memory.Address.Count(UInt(_stride))

        guard _arena.allocate(count: byteCount, alignment: alignment) != nil else {
            return nil
        }

        let slot = _allocated.map(Ordinal.init)
        _initializationBits[slot.retag(Bit.self)] = true
        _allocated += .one
        return slot
    }
}

// MARK: - Deinitialize Accessor

extension Storage.Arena where Element: ~Copyable {
    /// Accessor for tracked deinitialize operations.
    ///
    /// Provides `.deinitialize.all()` for safe cleanup.
    ///
    /// ```swift
    /// arena.deinitialize.all()  // Deinitializes all elements, resets arena
    /// ```
    @inlinable
    public var `deinitialize`: Property<Storage.Deinitialize, Storage.Arena> {
        Property(self)
    }
}

// MARK: - Deinitialize Methods

extension Property {
    /// Deinitializes all allocated elements and resets the arena.
    ///
    /// After this call, all slots are uninitialized and the arena is empty.
    /// The arena reuses the same backing storage.
    ///
    /// - Complexity: O(k) where k is the number of allocated slots.
    @inlinable
    public func all<Element: ~Copyable>()
    where Tag == Storage<Element>.Deinitialize, Base == Storage<Element>.Arena {
        base._initializationBits.ones.forEach { bitIndex in
            unsafe base.pointer(at: bitIndex.retag(Element.self)).deinitialize(count: .one)
        }
        base._initializationBits.clear.all()
        base._arena.reset()
        base._allocated = .zero
    }
}

// MARK: - Sendable

extension Storage.Arena: @unchecked Sendable where Element: Sendable {}
