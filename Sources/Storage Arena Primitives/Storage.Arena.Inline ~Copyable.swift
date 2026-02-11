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
public import Finite_Primitives
internal import Property_Primitives

// MARK: - Properties

extension Storage.Arena.Inline where Element: ~Copyable {
    /// Storage capacity in slot count.
    ///
    /// Runtime-accessible view of the compile-time `capacity` parameter.
    @inlinable
    public var slotCapacity: Index<Element>.Count {
        Index<Element>.Count(Cardinal(UInt(capacity)))
    }

    /// Number of currently allocated (initialized) slots.
    @inlinable
    public var allocated: Index<Element>.Count { _allocated }

    /// Number of remaining (unallocated) slots.
    @inlinable
    public var remaining: Index<Element>.Count {
        slotCapacity.subtract.saturating(_allocated)
    }

    /// Whether no slots are allocated.
    @inlinable
    public var isEmpty: Bool { _allocated == .zero }
}

// MARK: - Operations

extension Storage.Arena.Inline where Element: ~Copyable {
    /// Allocates the next slot and returns its bounded index.
    ///
    /// The returned slot contains uninitialized memory — the caller must
    /// initialize it before use. Allocation is sequential: slot 0, then 1, etc.
    ///
    /// - Returns: Bounded index of the allocated slot, or `nil` if the arena is full.
    /// - Complexity: O(1)
    @inlinable
    public mutating func allocate() -> Index<Element>.Bounded<capacity>? {
        let slotCapacity = slotCapacity
        guard _allocated < slotCapacity else { return nil }

        let slot = _allocated.map(Ordinal.init)
        let bitIndex = slot.retag(Bit.self)
        _slots[bitIndex] = true
        _allocated += .one
        return Index<Element>.Bounded<capacity>(slot)
    }
}

// MARK: - Deinitialize Accessor

extension Storage.Arena.Inline where Element: ~Copyable {
    /// Accessor for tracked deinitialize operations.
    ///
    /// Provides `.deinitialize.all()` for safe cleanup.
    ///
    /// ```swift
    /// arena.deinitialize.all()  // Deinitializes all elements, resets arena
    /// ```
    @inlinable
    public var `deinitialize`: Property<Storage.Deinitialize, Self>.View {
        mutating _read {
            yield unsafe Property<Storage.Deinitialize, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Storage.Deinitialize, Self>.View(&self)
            yield &view
        }
    }
}

// MARK: - Deinitialize Methods

extension Property.View where Base: ~Copyable {
    /// Deinitializes all allocated elements and resets the arena.
    ///
    /// Iterates the bit vector and deinitializes exactly those slots
    /// that are tracked as allocated. After this call, all slots are
    /// unallocated and the arena is empty.
    ///
    /// - Complexity: O(k) where k is the number of allocated slots.
    @inlinable
    @_lifetime(&self)
    public mutating func all<Element: ~Copyable, let capacity: Int>()
    where Tag == Storage<Element>.Deinitialize, Base == Storage<Element>.Arena.Inline<capacity> {
        unsafe base.pointee._slots.ones.forEach { bitIndex in
            unsafe base.pointee._pointer(at: bitIndex.retag(Element.self)).deinitialize(count: .one)
        }
        unsafe base.pointee._slots.clear.all()
        unsafe base.pointee._allocated = .zero
    }
}
