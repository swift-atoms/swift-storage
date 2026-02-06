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
public import Property_Primitives
public import Bit_Vector_Primitives

// MARK: - Deinitialize Accessor

extension Storage.Inline where Element: ~Copyable {
    /// Accessor for tracked deinitialize operations.
    ///
    /// Provides both `.deinitialize()` and `.deinitialize.all()` for cleanup.
    ///
    /// ```swift
    /// storage.deinitialize()      // Deinitializes all elements via callAsFunction
    /// storage.deinitialize.all()  // Same effect via named method
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
    /// Deinitializes the element at the given slot.
    ///
    /// - Parameter slot: The slot to deinitialize.
    /// - Precondition: The slot must be initialized.
    /// - Note: Automatically clears the slot's tracking bit.
    @inlinable
    @_lifetime(&self)
    public mutating func callAsFunction<
        Element: ~Copyable,
        let capacity: Int
    >(at slot: Index<Element>) where Tag == Storage<Element>.Deinitialize, Base == Storage<Element>.Inline<capacity> {
        unsafe UnsafeMutablePointer(mutating: base.pointee.pointer(at: slot)).deinitialize(count: 1)
        unsafe base.pointee._slots[slot.retag()] = false
    }
    
    /// Deinitializes all elements in the given range.
    ///
    /// - Parameter range: The contiguous range of slots to deinitialize.
    /// - Precondition: All slots in the range must contain initialized elements.
    /// - Note: Automatically clears each slot's tracking bit.
    @inlinable
    @_lifetime(&self)
    public mutating func callAsFunction<Element: ~Copyable, let capacity: Int>(
        range: Swift.Range<Index<Element>>
    ) where Tag == Storage<Element>.Deinitialize, Base == Storage<Element>.Inline<capacity> {
        guard !range.isEmpty else { return }
        unsafe UnsafeMutablePointer(
            mutating: base.pointee.pointer(at: range.lowerBound)
        ).deinitialize(count: range.count)
        unsafe base.pointee._slots.clear.range(range.map.bounds { $0.retag(Bit.self) })
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
    @_lifetime(&self)
    public mutating func all<Element: ~Copyable, let capacity: Int>()
    where Tag == Storage<Element>.Deinitialize, Base == Storage<Element>.Inline<capacity> {
        unsafe base.pointee._slots.ones.forEach { bitIndex in
            unsafe UnsafeMutablePointer(
                mutating: base.pointee.pointer(at: bitIndex.retag(Element.self))
            ).deinitialize(count: 1)
        }
        unsafe base.pointee._slots.clear.all()
    }
}
