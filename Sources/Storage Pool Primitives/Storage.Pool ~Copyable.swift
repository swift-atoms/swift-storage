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

// MARK: - Free List Sentinel

extension Storage.Pool where Element: ~Copyable {
    /// The end-of-list sentinel: one-past-last valid slot index.
    ///
    /// Analogous to `endIndex` in Swift collections. A free list link
    /// equal to the sentinel means "no next free slot." Derived from
    /// capacity — not an arbitrary magic constant.
    @inlinable
    internal var _sentinel: Index<Element> { _capacity.map(Ordinal.init) }
}

// MARK: - Pointer Primitive

extension Storage.Pool where Element: ~Copyable {
    /// Returns a mutable pointer to the element at the given slot index.
    ///
    /// - Parameter slot: A slot index. Must be < capacity.
    /// - Returns: Mutable pointer to the element's memory.
    /// - Precondition: `slot` is within bounds.
    @unsafe
    @inlinable
    public func pointer(at slot: Index<Element>) -> UnsafeMutablePointer<Element> {
        precondition(slot < _sentinel, "Slot index out of bounds")
        return unsafe _storage + Index<Element>.Offset(fromZero: slot)
    }

    /// Returns an immutable pointer to the element at the given slot index.
    ///
    /// - Parameter slot: A slot index. Must be < capacity.
    /// - Returns: Immutable pointer to the element's memory.
    /// - Precondition: `slot` is within bounds.
    @unsafe
    @inlinable
    @_disfavoredOverload
    public func pointer(at slot: Index<Element>) -> UnsafePointer<Element> {
        precondition(slot < _sentinel, "Slot index out of bounds")
        return unsafe UnsafePointer(_storage + Index<Element>.Offset(fromZero: slot))
    }
}

// MARK: - Properties

extension Storage.Pool where Element: ~Copyable {
    /// Total number of element slots.
    @inlinable
    public var capacity: Index<Element>.Count { _capacity }

    /// Number of currently allocated (in-use) slots.
    @inlinable
    public var allocated: Index<Element>.Count { _allocated }

    /// Number of available (free + virgin) slots.
    @inlinable
    public var available: Index<Element>.Count {
        _capacity.subtract.saturating(_allocated)
    }

    /// Whether all slots are allocated.
    @inlinable
    public var isExhausted: Bool {
        _freeHead == _sentinel && _nextUnused >= _sentinel
    }

    /// Whether no slots are allocated.
    @inlinable
    public var isEmpty: Bool {
        _allocated == .zero
    }
}

// MARK: - Operations

extension Storage.Pool where Element: ~Copyable {
    /// Allocates a slot and returns its index.
    ///
    /// Prefers reusing freed slots (free list). Falls back to virgin cursor.
    /// The returned slot contains uninitialized memory — the caller must
    /// initialize it before use.
    ///
    /// - Returns: Index of the allocated slot.
    /// - Throws: `.exhausted` if no free or virgin slots remain.
    /// - Complexity: O(1)
    @inlinable
    public func allocate() throws(Error) -> Index<Element> {
        // Try free list first (reused slots)
        if _freeHead != _sentinel {
            let slot = _freeHead
            let raw = unsafe UnsafeMutableRawPointer(_storage + Index<Element>.Offset(fromZero: slot))
            _freeHead = unsafe raw.load(as: Index<Element>.self)
            _allocationBits[slot.retag(Bit.self)] = true
            _allocated += .one
            return slot
        }

        // Try virgin cursor
        guard _nextUnused < _sentinel else {
            throw .exhausted(capacity: _capacity)
        }

        let slot = _nextUnused
        _nextUnused = _nextUnused + .one
        _allocationBits[slot.retag(Bit.self)] = true
        _allocated += .one
        return slot
    }

    /// Returns a slot to the free list.
    ///
    /// The caller MUST deinitialize any element stored in the slot
    /// before calling this method.
    ///
    /// - Parameter slot: A slot index previously returned by `allocate()`.
    /// - Throws: `.doubleFree` if the slot is already free.
    /// - Complexity: O(1)
    @inlinable
    public func deallocate(at slot: Index<Element>) throws(Error) {
        let bitIndex = slot.retag(Bit.self)
        guard _allocationBits[bitIndex] else {
            throw .doubleFree
        }

        // Clear allocation bit.
        _allocationBits[bitIndex] = false

        // Push current head into this slot, make slot new head (LIFO).
        let raw = unsafe UnsafeMutableRawPointer(_storage + Index<Element>.Offset(fromZero: slot))
        unsafe raw.storeBytes(of: _freeHead, as: Index<Element>.self)
        _freeHead = slot
        _allocated = _allocated.subtract.saturating(.one)
    }

    /// Deinitializes all allocated elements and resets the pool.
    ///
    /// After this call, all slots are uninitialized and available.
    /// The pool reuses the same backing storage.
    ///
    /// - Complexity: O(k) where k is the number of allocated slots.
    @inlinable
    public func deinitializeAll() {
        for bitIndex in _allocationBits.ones {
            let slot = bitIndex.retag(Element.self)
            unsafe (_storage + Index<Element>.Offset(fromZero: slot))
                .deinitialize(count: 1)
        }
        _allocationBits.clear.all()
        _freeHead = _capacity.map(Ordinal.init) // sentinel
        _nextUnused = .zero
        _allocated = .zero
    }

    /// Resets the pool, deinitializing all allocated elements.
    ///
    /// Equivalent to ``deinitializeAll()``.
    @inlinable
    public func reset() {
        deinitializeAll()
    }
}

// MARK: - Sendable

extension Storage.Pool: @unchecked Sendable where Element: Sendable {}
