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
internal import Property_Primitives
public import Bit_Vector_Static_Primitives
public import Vector_Primitives_Core

// MARK: - Deinitialize Accessor

extension Storage.Inline where Element: ~Copyable {
    /// Accessor for deinitialize operations.
    ///
    /// Non-mutating `get` enables use in `deinit` contexts:
    /// ```swift
    /// deinit { unsafe storage.deinitialize() }
    /// ```
    ///
    /// Mutating `_modify` enables tracked operations that clear bits:
    /// ```swift
    /// storage.deinitialize(at: slot)   // Single slot, clears tracking bit
    /// storage.deinitialize(range: r)   // Range, clears tracking bits
    /// storage.deinitialize.all()       // All slots, clears all tracking bits
    /// ```
    ///
    /// - Note: Uses `@_unsafeNonescapableResult` on `_read` because `~Escapable`
    ///   values with `@_lifetime(borrow base)` cannot exist in deinit scope.
    ///   The attribute suppresses lifetime-dependence diagnostics on the yielded
    ///   value. The `_read` coroutine is preferred over `get` because it yields
    ///   `@guaranteed` (no copy).
    ///   See: `Research/escapable-deinit-lifetime.md`
    @inlinable
    public var `deinitialize`: Property<Storage.Deinitialize, Self>.View {
        @_unsafeNonescapableResult
        _read {
            yield unsafe Property<Storage.Deinitialize, Self>.View(self)
        }
        mutating _modify {
            var view = unsafe Property<Storage.Deinitialize, Self>.View(&self)
            yield &view
        }
    }
}

// MARK: - Deinitialize Methods

extension Property.View where Base: ~Copyable {
    /// Deinitializes the element at the given bounded slot.
    ///
    /// Precondition-free — the bounded index guarantees validity.
    ///
    /// - Parameter slot: A bounded slot to deinitialize.
    /// - Precondition: The slot must be initialized.
    /// - Note: Automatically clears the slot's tracking bit.
    @inlinable
    public mutating func callAsFunction<
        Element: ~Copyable,
        let capacity: Int
    >(at slot: Index<Element>.Bounded<capacity>) where Tag == Storage<Element>.Deinitialize, Base == Storage<Element>.Inline<capacity> {
        unsafe base.value.pointer(at: slot).deinitialize(count: .one)
        unsafe base.value._slots[Index<Element>(slot).retag()] = false
    }
    
    /// Deinitializes all elements in the given range.
    ///
    /// - Parameter range: The contiguous range of slots to deinitialize.
    /// - Precondition: All slots in the range must contain initialized elements.
    /// - Note: Automatically clears each slot's tracking bit.
    @inlinable
    public mutating func callAsFunction<Element: ~Copyable, let capacity: Int>(
        range: Swift.Range<Index<Element>>
    ) where Tag == Storage<Element>.Deinitialize, Base == Storage<Element>.Inline<capacity> {
        guard !range.isEmpty else { return }
        unsafe base.value._mutablePointer(at: range.lowerBound)
            .deinitialize(count: range.count)
        unsafe base.value._slots.clear.range(range.map.bounds { $0.retag(Bit.self) })
    }
    
    
    /// Deinitializes all elements and resets to empty state.
    ///
    /// Iterates the bit vector and deinitializes exactly those slots
    /// that are tracked as initialized. Handles any initialization pattern
    /// (linear, sparse, disjoint).
    ///
    /// ```swift
    /// var storage = Storage<Int>.Inline<8>()
    /// storage.initialize.next(to: 1)
    /// storage.initialize.next(to: 2)
    /// storage.deinitialize.all()  // Elements deinitialized, state is now empty
    /// ```
    @inlinable
    public mutating func all<Element: ~Copyable, let capacity: Int>()
    where Tag == Storage<Element>.Deinitialize, Base == Storage<Element>.Inline<capacity> {
        for bitIndex in unsafe base.value._slots.ones {
            unsafe base.value._mutablePointer(at: bitIndex.retag(Element.self))
                .deinitialize(count: .one)
        }
        unsafe base.value._slots.clear.all()
    }

    /// Deinitializes all tracked slots without clearing tracking bits.
    ///
    /// Non-mutating — intended for `deinit` contexts where the storage
    /// is being consumed and no further state updates are needed.
    ///
    /// Iterates the per-slot bitvector and deinitializes exactly those
    /// slots that are tracked as initialized. Handles linear, sparse,
    /// and disjoint initialization patterns.
    ///
    /// ```swift
    /// deinit { unsafe storage.deinitialize() }
    /// ```
    @unsafe
    @inlinable
    public func callAsFunction<Element: ~Copyable, let capacity: Int>()
    where Tag == Storage<Element>.Deinitialize, Base == Storage<Element>.Inline<capacity> {
        for bitIndex in unsafe base.value._slots.ones {
            unsafe base.value._mutablePointer(at: bitIndex.retag(Element.self))
                .deinitialize(count: .one)
        }
    }
}
