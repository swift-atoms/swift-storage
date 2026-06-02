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

public import Bit_Vector_Static_Primitives
public import Finite_Bounded_Primitives
public import Index_Primitives
internal import Property_Primitives
public import Storage_Accessor_Primitives
public import Storage_Error_Primitives
public import Storage_Initialization_Primitives
public import Storage_Primitive

// MARK: - Initialize Accessor

extension Storage.Inline where Element: ~Copyable {
    /// Accessor for tracked initialize operations.
    ///
    /// Provides `.initialize.next(to:)` for linear discipline.
    ///
    /// ```swift
    /// var storage = Storage<Int>.Inline<8>()
    /// storage.initialize.next(to: 1)  // Stored at slot 0
    /// storage.initialize.next(to: 2)  // Stored at slot 1
    /// ```
    @inlinable
    public var initialize: Property<Storage.Initialize, Self>.Inout {
        mutating _read {
            yield Property<Storage.Initialize, Self>.Inout(&self)
        }
        mutating _modify {
            var accessor = Property<Storage.Initialize, Self>.Inout(&self)
            yield &accessor
        }
    }
}

// MARK: - Initialize Methods

extension Property.Inout where Base: ~Copyable {
    /// Initializes storage at the given bounded physical slot with the provided value.
    ///
    /// Precondition-free — the bounded index guarantees validity.
    ///
    /// - Parameters:
    ///   - element: The value to store.
    ///   - slot: A bounded physical slot to initialize.
    /// - Precondition: The element at `slot` must be uninitialized.
    /// - Note: Automatically marks the slot as initialized in the tracking bit vector.
    @inlinable
    public mutating func callAsFunction<Element: ~Copyable, let count: Int>(
        to element: consuming Element,
        at slot: Index<Element>.Bounded<count>
    ) where Tag == Storage<Element>.Initialize, Base == Storage<Element>.Inline<count> {
        unsafe base.value.pointer(at: slot).initialize(to: element)
        base.value._slots[Index<Element>(slot).retag()] = true
    }

    /// Initializes the next available slot with the given element.
    ///
    /// This method maintains linear discipline: elements are stored
    /// contiguously from slot 0. The bit vector is updated automatically
    /// via `Storage.Inline.initialize(to:at:)`.
    ///
    /// ```swift
    /// var storage = Storage<Int>.Inline<8>()
    /// try storage.initialize.next(to: 1)  // Stored at slot 0
    /// try storage.initialize.next(to: 2)  // Stored at slot 1
    /// ```
    ///
    /// - Parameter element: The value to store.
    /// - Returns: The bounded slot where the element was stored.
    /// - Throws: ``Storage/Error/capacityExceeded`` if storage is full.
    ///   If thrown, the `consuming` element is destroyed (callee owns it).
    ///   For `~Copyable` elements, verify capacity before calling.
    @inlinable
    @discardableResult
    public mutating func next<Element: ~Copyable, let count: Int>(
        to element: consuming Element
    ) throws(Storage<Element>.Error) -> Index<Element>.Bounded<count>
    where Tag == Storage<Element>.Initialize, Base == Storage<Element>.Inline<count> {
        let slot = base.value.initialization.count.map(Ordinal.init)
        guard slot < base.value.capacity else { throw .capacityExceeded }
        // WHY: slot is provably < count — the guard above rejects slot >= capacity (== count).
        // swift-format-ignore: NeverForceUnwrap
        let bounded = Index<Element>.Bounded<count>(slot)!
        self(to: element, at: bounded)
        return bounded
    }
}
