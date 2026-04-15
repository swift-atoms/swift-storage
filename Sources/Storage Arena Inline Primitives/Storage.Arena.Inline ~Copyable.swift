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
public import Bit_Vector_Static_Primitives
internal import Finite_Primitives
internal import Property_Primitives
public import Memory_Primitives_Standard_Library_Integration

// MARK: - Pointer Access

extension Storage.Arena.Inline where Element: ~Copyable {
    /// Returns a mutable pointer to the element at the given bounded slot.
    ///
    /// Precondition-free — the bounded index guarantees validity.
    ///
    /// - Parameter slot: A bounded slot index returned by `allocate()`.
    /// - Returns: Mutable pointer to the element's memory.
    @unsafe
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
    @inlinable
    @_disfavoredOverload
    public func pointer(at slot: Index<Element>.Bounded<capacity>) -> UnsafePointer<Element> {
        unsafe UnsafePointer(pointer(at: Index<Element>(slot)))
    }

    /// Internal unbounded pointer for deinit iteration.
    @unsafe
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

extension Storage.Arena.Inline where Element: ~Copyable {
    /// Storage capacity in slot count.
    ///
    /// Runtime-accessible view of the compile-time `capacity` parameter.
    @inlinable
    public var slotCapacity: Index<Element>.Count {
        try! Index<Element>.Count(capacity)
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
    /// The allocation is recorded as initialized for teardown purposes: if the
    /// arena is deinitialized before the caller initializes this slot, `deinit`
    /// will attempt to deinitialize uninitialized memory (undefined behavior).
    ///
    /// If initialization can fail, use ``unallocate(_:)`` to roll back the
    /// most recent allocation on the failure path.
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

    /// Rolls back the most recent allocation.
    ///
    /// Only valid for the slot returned by the immediately preceding
    /// ``allocate()`` call. The slot must not have been initialized.
    ///
    /// - Parameter slot: The bounded slot returned by the last `allocate()` call.
    /// - Precondition: `slot` is the most recently allocated slot.
    /// - Precondition: The slot has not been initialized.
    @inlinable
    public mutating func unallocate(_ slot: Index<Element>.Bounded<capacity>) {
        let decremented = _allocated.subtract.saturating(.one)
        let index = Index<Element>(slot)
        precondition(index == decremented.map(Ordinal.init), "unallocate requires the most recently allocated slot")
        _slots[index.retag(Bit.self)] = false
        _allocated = decremented
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
    public mutating func all<Element: ~Copyable, let capacity: Int>()
    where Tag == Storage<Element>.Deinitialize, Base == Storage<Element>.Arena.Inline<capacity> {
        for bitIndex in unsafe base.pointee._slots.ones {
            unsafe base.pointee.pointer(at: bitIndex.retag(Element.self)).deinitialize(count: .one)
        }
        unsafe base.pointee._slots.clear.all()
        unsafe base.pointee._allocated = .zero
    }
}

// MARK: - Sendable

// WHY: Category D — structural Sendable workaround (SP-2).
// WHY: `Storage.Arena.Inline._Raw` is a @_rawLayout wrapper. @_rawLayout
// WHY: blocks structural Sendable inference. No caller invariant.
// WHEN TO REMOVE: When compiler gains structural Sendable inference through
// WHEN TO REMOVE: @_rawLayout types.
// TRACKING: unsafe-audit-findings.md Category D SP-2.
extension Storage.Arena.Inline._Raw: @unchecked Sendable where Element: Sendable {}

/// Sendable conformance for `Storage.Arena.Inline`.
///
/// ## Safety Invariant
///
/// `~Copyable` guarantees single ownership. The inline arena buffer and its
/// slot-tracking state travel together as one unit during moves. Cross-thread
/// transfer relinquishes the sender's access.
///
/// ## Intended Use
///
/// - Moving a fixed-capacity inline arena from a producer thread to a
///   consumer thread as a one-shot transfer.
///
/// ## Non-Goals
///
/// Does NOT support concurrent access. Single-owner semantics only.
extension Storage.Arena.Inline: @unsafe @unchecked Sendable where Element: Sendable {}
