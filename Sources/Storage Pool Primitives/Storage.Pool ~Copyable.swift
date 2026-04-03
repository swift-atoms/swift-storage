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
internal import Bit_Vector_Primitives_Core
internal import Property_Primitives

// MARK: - Pointer Primitive

extension Storage.Pool where Element: ~Copyable {
    /// Returns an immutable pointer to the element at the given slot index.
    ///
    /// - Parameter slot: A slot index. Must be < capacity.
    /// - Returns: Immutable pointer to the element's memory.
    /// - Precondition: `slot` is within bounds.
    @unsafe
    @inlinable
    @_disfavoredOverload
    public func pointer(at slot: Index<Element>) -> UnsafePointer<Element> {
        unsafe UnsafePointer(
            _pool.pointer(at: slot.retag(Memory.Pool.Slot.self))
                .assumingMemoryBound(to: Element.self)
        )
    }
}

// MARK: - Properties

extension Storage.Pool where Element: ~Copyable {
    /// Total number of element slots.
    @inlinable
    public var capacity: Index<Element>.Count { _pool.capacity.retag(Element.self) }

    /// Number of currently allocated (in-use) slots.
    @inlinable
    public var allocated: Index<Element>.Count { _pool.allocated.retag(Element.self) }

    /// Number of available (free + virgin) slots.
    @inlinable
    public var available: Index<Element>.Count { _pool.available.retag(Element.self) }

    /// Whether all slots are allocated.
    @inlinable
    public var isExhausted: Bool { _pool.isExhausted }

    /// Whether no slots are allocated.
    @inlinable
    public var isEmpty: Bool { _pool.allocated == .zero }
}

// MARK: - Operations

extension Storage.Pool where Element: ~Copyable {
    /// Allocates a slot and returns its index.
    ///
    /// Prefers reusing freed slots (free list). Falls back to virgin cursor.
    /// The returned slot contains uninitialized memory — the caller must
    /// initialize it before use.
    ///
    /// The allocation is recorded for teardown purposes: if the pool is
    /// deinitialized before the caller initializes this slot, `deinit` will
    /// attempt to deinitialize uninitialized memory (undefined behavior).
    ///
    /// If initialization can fail, call ``deallocate(at:)`` on the failure
    /// path to return the uninitialized slot to the free list.
    ///
    /// - Returns: Index of the allocated slot.
    /// - Throws: `.exhausted` if no free or virgin slots remain.
    /// - Complexity: O(1)
    @inlinable
    public func allocate() throws(Error) -> Index<Element> {
        do {
            return try _pool.allocateSlot().retag(Element.self)
        } catch {
            switch error {
            case .exhausted(let capacity):
                throw .exhausted(capacity: capacity.retag(Element.self))
            case .invalidCapacity, .slotSizeTooSmall, .foreignPointer, .doubleFree:
                fatalError("Unreachable: \(error)")
            }
        }
    }

    /// Returns a slot to the free list.
    ///
    /// The caller MUST deinitialize any element stored in the slot
    /// before calling this method. If the slot was never initialized
    /// (e.g., allocation succeeded but initialization failed), calling
    /// this method is safe — there is nothing to deinitialize, and the
    /// slot is returned to the free list.
    ///
    /// - Parameter slot: A slot index previously returned by `allocate()`.
    /// - Throws: `.doubleFree` if the slot is already free.
    /// - Complexity: O(1)
    @inlinable
    public func deallocate(at slot: Index<Element>) throws(Error) {
        do {
            try _pool.deallocate(at: slot.retag(Memory.Pool.Slot.self))
        } catch {
            switch error {
            case .doubleFree:
                throw .doubleFree
            case .exhausted, .invalidCapacity, .slotSizeTooSmall, .foreignPointer:
                fatalError("Unreachable: \(error)")
            }
        }
    }

}

// MARK: - Deinitialize Accessor

extension Storage.Pool where Element: ~Copyable {
    /// Accessor for tracked deinitialize operations.
    ///
    /// Provides `.deinitialize.all()` for safe cleanup.
    ///
    /// ```swift
    /// pool.deinitialize.all()  // Deinitializes all elements, resets pool
    /// ```
    @inlinable
    public var `deinitialize`: Property<Storage.Deinitialize, Storage.Pool> {
        Property(self)
    }
}

// MARK: - Deinitialize Methods

extension Property {
    /// Deinitializes all allocated elements and resets the pool.
    ///
    /// After this call, all slots are uninitialized and available.
    /// The pool reuses the same backing storage.
    ///
    /// - Complexity: O(k) where k is the number of allocated slots.
    @inlinable
    public func all<Element: ~Copyable>()
    where Tag == Storage<Element>.Deinitialize, Base == Storage<Element>.Pool {
        for bitIndex in base._pool.allocation.indices {
            unsafe base.pointer(at: bitIndex.retag(Element.self)).deinitialize(count: .one)
        }
        base._pool.reset()
    }
}

// MARK: - Sendable

extension Storage.Pool: @unchecked Sendable where Element: Sendable {}
