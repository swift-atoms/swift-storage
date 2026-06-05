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

public import Index_Primitives
internal import Property_Primitives
public import Storage_Accessor_Primitives
public import Storage_Error_Primitives
public import Storage_Initialization_Primitives
public import Memory_Heap_Primitives
public import Storage_Primitive

// MARK: - Initialize Accessor

extension Storage.Contiguous where Element: ~Copyable, Substrate == Memory.Heap<Element> {
    /// Accessor for tracked initialize operations.
    ///
    /// Provides `.initialize.next(to:)` for linear discipline.
    ///
    /// ```swift
    /// let slot = try heap.initialize.next(to: value)  // Initializes next slot, updates state
    /// ```
    ///
    /// - Note: For `~Copyable` elements the Heap is uniquely owned and never
    ///   value-copied, so this accessor mutates the backing buffer directly. The
    ///   `Element: Copyable` overload triggers copy-on-write first (see below).
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

extension Storage.Contiguous where Element: Copyable, Substrate == Memory.Heap<Element> {
    /// Copy-on-write accessor for tracked initialize operations.
    ///
    /// Triggers `ensureUnique()` before yielding the mutator so a value-copied
    /// Copyable Heap copies-on-write before any slot is initialized. Swift selects
    /// this more-constrained overload at concrete `Copyable`-element call sites;
    /// `~Copyable` Heaps use the direct overload above. This is the single
    /// choke point for initialize-path CoW — every `initialize.*` mutation flows
    /// through the yielded `Property.Inout`.
    @inlinable
    public var initialize: Property<Storage.Initialize, Self>.Inout {
        mutating _read {
            ensureUnique()
            yield Property<Storage.Initialize, Self>.Inout(&self)
        }
        mutating _modify {
            ensureUnique()
            var accessor = Property<Storage.Initialize, Self>.Inout(&self)
            yield &accessor
        }
    }
}

extension Property.Inout where Base: ~Copyable {

    /// Initializes storage at the given physical slot with the provided value.
    ///
    /// - Parameters:
    ///   - element: The value to store.
    ///   - slot: The physical slot to initialize.
    /// - Precondition: The element at `slot` must be uninitialized.
    /// - Note: The caller is responsible for updating `initialization` state.
    @inlinable
    public mutating func callAsFunction<Element: ~Copyable>(
        to element: consuming Element,
        at slot: Index<Element>
    ) where Tag == Storage<Element>.Initialize, Base == Storage<Element>.Contiguous<Memory.Heap<Element>> {
        unsafe base.value.pointer(at: slot).initialize(to: element)
    }
}

// MARK: - Initialize Methods

extension Property.Inout where Base: ~Copyable {
    /// Initializes the next available slot with the given element.
    ///
    /// This method maintains linear discipline: elements are stored
    /// contiguously from slot 0. The initialization state is updated
    /// automatically.
    ///
    /// ```swift
    /// var heap = Storage<Int>.Contiguous<Memory.Heap<Int>>.create(minimumCapacity: 8)
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
    public mutating func next<Element: ~Copyable>(to element: consuming Element) throws(Storage<Element>.Error) -> Index<Element>
    where Tag == Storage<Element>.Initialize, Base == Storage<Element>.Contiguous<Memory.Heap<Element>> {
        let currentCount = base.value.initialization.count
        let slot = currentCount.map(Ordinal.init)
        guard slot < base.value.capacity else { throw .capacityExceeded }
        self(to: element, at: slot)
        base.value.initialization = .linear(count: currentCount + .one)
        return slot
    }
}
