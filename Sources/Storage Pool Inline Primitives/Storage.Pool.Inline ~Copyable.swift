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

// MARK: - Pointer Access

extension Storage.Pool.Inline where Element: ~Copyable {
    /// Returns a mutable pointer to the element at the given bounded slot.
    ///
    /// Precondition-free — the bounded index guarantees validity.
    ///
    /// - Parameter slot: A bounded slot index returned by `allocate()`.
    /// - Returns: Mutable pointer to the element's memory.
    @unsafe
    @_lifetime(borrow self)
    @inlinable
    public func pointer(at slot: Index<Element>.Bounded<capacity>) -> UnsafeMutablePointer<Element> {
        unsafe pointer(at: Index<Element>(slot))
    }

    /// Returns an immutable pointer to the element at the given bounded slot.
    ///
    /// Precondition-free — the bounded index guarantees validity.
    ///
    /// - Parameter slot: A bounded slot index returned by `allocate()`.
    /// - Returns: Immutable pointer to the element's memory.
    @unsafe
    @_lifetime(borrow self)
    @inlinable
    @_disfavoredOverload
    public func pointer(at slot: Index<Element>.Bounded<capacity>) -> UnsafePointer<Element> {
        unsafe UnsafePointer(pointer(at: Index<Element>(slot)))
    }

    /// Internal unbounded pointer for deinit iteration.
    @unsafe
    @_lifetime(borrow self)
    @inlinable
    package func pointer(at slot: Index<Element>) -> UnsafeMutablePointer<Element> {
        unsafe withUnsafePointer(to: _storage) { base in
            unsafe UnsafeMutablePointer(mutating:
                UnsafeRawPointer(base)
                    .advanced(by: Index<Element>.Offset(fromZero: slot) * .stride)
                    .assumingMemoryBound(to: Element.self)
            )
        }
    }
}

// MARK: - Properties

extension Storage.Pool.Inline where Element: ~Copyable {
    /// Storage capacity in slot count.
    ///
    /// Runtime-accessible view of the compile-time `capacity` parameter.
    @inlinable
    public var slotCapacity: Index<Element>.Count {
        try! Index<Element>.Count(capacity)
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
    /// The allocation is recorded for teardown purposes: if the pool is
    /// deinitialized before the caller initializes this slot, `deinit` will
    /// attempt to deinitialize uninitialized memory (undefined behavior).
    ///
    /// If initialization can fail, call ``deallocate(at:)`` on the failure
    /// path to return the uninitialized slot to the pool.
    ///
    /// - Returns: Bounded index of the allocated slot.
    /// - Throws: `.exhausted` if no free slots remain.
    /// - Complexity: O(capacity / 64) worst case (word-level bitmap scan).
    @inlinable
    public mutating func allocate() throws(Storage.Pool.Error) -> Index<Element>.Bounded<capacity> {
        let slotCapacity = slotCapacity
        guard _allocated < slotCapacity else {
            throw .exhausted(capacity: slotCapacity)
        }

        let bitIndex = _slots.zeros.first!
        _slots[bitIndex] = true
        _allocated += .one
        return Index<Element>.Bounded<capacity>(bitIndex.retag(Element.self))!
    }

    /// Returns a slot to the pool.
    ///
    /// The caller MUST move or deinitialize any element stored in the slot
    /// before calling this method. If the slot was never initialized
    /// (e.g., allocation succeeded but initialization failed), calling
    /// this method is safe — there is nothing to deinitialize, and the
    /// slot is returned to the pool.
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
        for bitIndex in unsafe base.pointee._slots.ones {
            unsafe base.pointee.pointer(at: bitIndex.retag(Element.self)).deinitialize(count: .one)
        }
        unsafe base.pointee._slots.clear.all()
        unsafe base.pointee._allocated = .zero
    }
}

// MARK: - Sendable

// @_rawLayout types require @unchecked Sendable
extension Storage.Pool.Inline._Raw: @unchecked Sendable where Element: Sendable {}
extension Storage.Pool.Inline: @unchecked Sendable where Element: Sendable {}
