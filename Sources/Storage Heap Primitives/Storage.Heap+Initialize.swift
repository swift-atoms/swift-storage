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

// MARK: - Initialize Accessor

extension Storage.Heap where Element: ~Copyable {
    /// Accessor for tracked initialize operations.
    ///
    /// Provides `.initialize.next(to:)` for linear discipline.
    ///
    /// ```swift
    /// let slot = heap.initialize.next(to: value)  // Initializes next slot, updates state
    /// ```
    @inlinable
    public var initialize: Property<Storage.Initialize, Storage.Heap> {
        Property(self)
    }
}

extension Property {
    
    /// Initializes storage at the given physical slot with the provided value.
    ///
    /// - Parameters:
    ///   - element: The value to store.
    ///   - slot: The physical slot to initialize.
    /// - Precondition: The element at `slot` must be uninitialized.
    /// - Note: The caller is responsible for updating `initialization` state.
    @inlinable
    public func callAsFunction<Element: ~Copyable>(
        to element: consuming Element,
        at slot: Index<Element>
    ) where Tag == Storage<Element>.Initialize, Base == Storage<Element>.Heap {
        unsafe base.pointer(at: slot).initialize(to: element)
    }
}

// MARK: - Initialize Methods


extension Property {
    /// Initializes the next available slot with the given element.
    ///
    /// This method maintains linear discipline: elements are stored
    /// contiguously from slot 0. The initialization state is updated
    /// automatically.
    ///
    /// ```swift
    /// var heap = Storage<Int>.Heap.create(minimumCapacity: 8)
    /// try heap.initialize.next(to: 1)  // Stored at slot 0
    /// try heap.initialize.next(to: 2)  // Stored at slot 1
    /// ```
    ///
    /// - Parameter element: The value to store.
    /// - Returns: The slot where the element was stored.
    /// - Throws: ``Storage/Error/capacityExceeded`` if storage is full.
    ///   If thrown, the `consuming` element is destroyed (callee owns it).
    ///   For `~Copyable` elements, verify capacity before calling.
    @inlinable
    @discardableResult
    public func next<Element: ~Copyable>(to element: consuming Element) throws(Storage<Element>.Error) -> Index<Element>
    where Tag == Storage<Element>.Initialize, Base == Storage<Element>.Heap {
        let currentCount = base.initialization.count
        let slot = currentCount.map(Ordinal.init)
        guard slot < base.slotCapacity else { throw .capacityExceeded }
        base.initialize(to: element, at: slot)
        base.initialization = .linear(count: currentCount + .one)
        return slot
    }
}
