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

extension Storage.Pool.Inline where Element: ~Copyable {
    /// Storage capacity in slot count.
    ///
    /// Runtime-accessible view of the compile-time `capacity` parameter.
    @inlinable
    public var slotCapacity: Index<Element>.Count {
        Index<Element>.Count(Cardinal(UInt(capacity)))
    }

    /// Number of currently allocated (in-use) slots.
    @inlinable
    public var allocated: Index<Element>.Count { _allocated }

    /// Number of available (unallocated) slots.
    @inlinable
    public var available: Index<Element>.Count {
        slotCapacity.subtract.saturating(_allocated)
    }

    /// Whether all slots are allocated.
    @inlinable
    public var isExhausted: Bool { _allocated >= slotCapacity }

    /// Whether no slots are allocated.
    @inlinable
    public var isEmpty: Bool { _allocated == .zero }
}

// MARK: - Operations

extension Storage.Pool.Inline where Element: ~Copyable {
    /// Allocates a slot and returns its bounded index.
    ///
    /// Scans the bitmap for the first unallocated slot. The returned slot
    /// contains uninitialized memory — the caller must initialize it before use.
    ///
    /// - Returns: Bounded index of the allocated slot.
    /// - Throws: `.exhausted` if no free slots remain.
    /// - Complexity: O(capacity) worst case (bitmap scan).
    @inlinable
    public mutating func allocate() throws(Storage.Pool.Error) -> Index<Element>.Bounded<capacity> {
        let slotCapacity = slotCapacity
        guard _allocated < slotCapacity else {
            throw .exhausted(capacity: slotCapacity)
        }

        for i in 0..<capacity {
            let elementIndex = Index<Element>.Count(Cardinal(UInt(i))).map(Ordinal.init)
            let bitIndex = elementIndex.retag(Bit.self)
            if !_slots[bitIndex] {
                _slots[bitIndex] = true
                _allocated += .one
                return Index<Element>.Bounded<capacity>(elementIndex)!
            }
        }
        fatalError("Unreachable: _allocated < capacity but no unset bit found")
    }

    /// Returns a slot to the pool.
    ///
    /// The caller MUST move or deinitialize any element stored in the slot
    /// before calling this method.
    ///
    /// - Parameter slot: A bounded slot index previously returned by `allocate()`.
    /// - Throws: `.doubleFree` if the slot is already free.
    /// - Complexity: O(1)
    @inlinable
    public mutating func deallocate(at slot: Index<Element>.Bounded<capacity>) throws(Storage.Pool.Error) {
        let bitIndex = Index<Element>(slot).retag(Bit.self)
        guard _slots[bitIndex] else { throw .doubleFree }
        _slots[bitIndex] = false
        _allocated = _allocated.subtract.saturating(.one)
    }
}

// MARK: - Deinitialize Accessor

extension Storage.Pool.Inline where Element: ~Copyable {
    /// Accessor for tracked deinitialize operations.
    ///
    /// Provides `.deinitialize.all()` for safe cleanup.
    ///
    /// ```swift
    /// pool.deinitialize.all()  // Deinitializes all elements, resets pool
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
    /// Deinitializes all allocated elements and resets the pool.
    ///
    /// Iterates the bit vector and deinitializes exactly those slots
    /// that are tracked as allocated. After this call, all slots are
    /// unallocated and available.
    ///
    /// - Complexity: O(k) where k is the number of allocated slots.
    @inlinable
    @_lifetime(&self)
    public mutating func all<Element: ~Copyable, let capacity: Int>()
    where Tag == Storage<Element>.Deinitialize, Base == Storage<Element>.Pool.Inline<capacity> {
        unsafe base.pointee._slots.ones.forEach { bitIndex in
            unsafe base.pointee._pointer(at: bitIndex.retag(Element.self)).deinitialize(count: .one)
        }
        unsafe base.pointee._slots.clear.all()
        unsafe base.pointee._allocated = .zero
    }
}
