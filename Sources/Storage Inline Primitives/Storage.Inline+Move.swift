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
public import Vector_Primitives_Core

// MARK: - Move Accessor

extension Storage.Inline where Element: ~Copyable {
    /// Accessor for tracked move operations.
    ///
    /// Provides `.move.last()` for linear discipline.
    ///
    /// ```swift
    /// let element = storage.move.last()  // Moves last element, updates state
    /// ```
    @inlinable
    public var move: Property<Storage.Move, Self>.View {
        mutating _read {
            yield unsafe Property<Storage.Move, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Storage.Move, Self>.View(&self)
            yield &view
        }
    }
}

// MARK: - Move Methods

extension Property.View where Base: ~Copyable {
    /// Moves elements from a range to the destination heap storage starting at offset.
    ///
    /// Elements from the source range are placed at slots offset..<(offset + range.count)
    /// in the destination storage. Source slots are deinitialized after moving.
    ///
    /// - Parameters:
    ///   - range: The contiguous range of slots to move from.
    ///   - destination: The destination heap storage.
    ///   - offset: The destination slot to start writing at.
    /// - Precondition: All slots in the range must contain initialized elements.
    /// - Precondition: Destination slots offset..<(offset + range.count) must be uninitialized.
    /// - Note: Automatically clears slot tracking bits for moved slots.
    /// - Note: Caller must update destination's initialization state.
    @inlinable
    @_lifetime(&self)
    public mutating func callAsFunction<Element: ~Copyable, let capacity: Int>(
        range: Swift.Range<Index<Element>>,
        to destination: Storage<Element>.Heap,
        at offset: Index<Element>
    ) where Tag == Storage<Element>.Move, Base == Storage<Element>.Inline<capacity> {
        guard !range.isEmpty else { return }
        unsafe destination.pointer(at: offset)
            .move.initialize(
                from: base.pointee._mutablePointer(at: range.lowerBound),
                count: range.count
            )
        unsafe base.pointee._slots.clear.range(range.map.bounds { $0.retag(Bit.self) })
    }

    /// Moves elements in range to linear positions in destination heap storage.
    ///
    /// Elements from the source range are placed at slots 0..<range.count in the
    /// destination storage. Source slots are deinitialized after moving.
    ///
    /// - Parameters:
    ///   - range: The contiguous range of slots to move from.
    ///   - destination: The destination heap storage.
    /// - Precondition: All slots in the range must contain initialized elements.
    /// - Precondition: Destination slots 0..<range.count must be uninitialized.
    /// - Note: Automatically clears slot tracking bits for moved slots.
    /// - Note: Caller must update destination's initialization state.
    @inlinable
    @_lifetime(&self)
    public mutating func callAsFunction<Element: ~Copyable, let capacity: Int>(
        range: Swift.Range<Index<Element>>,
        to destination: Storage<Element>.Heap
    ) where Tag == Storage<Element>.Move, Base == Storage<Element>.Inline<capacity> {
        self(range: range, to: destination, at: .zero)
    }
    
    
    /// Moves the element at the given bounded physical slot, deinitializing that slot.
    ///
    /// Precondition-free — the bounded index guarantees validity.
    ///
    /// - Parameter slot: A bounded physical slot to move from.
    /// - Returns: The moved element.
    /// - Precondition: The element at `slot` must be initialized.
    /// - Note: Automatically marks the slot as uninitialized in the tracking bit vector.
    @inlinable
    @_lifetime(&self)
    public mutating func callAsFunction<Element: ~Copyable, let capacity: Int>(
        at slot: Index<Element>.Bounded<capacity>
    ) -> Element where Tag == Storage<Element>.Move, Base == Storage<Element>.Inline<capacity> {
        let element = unsafe base.pointee.pointer(at: slot).move()
        unsafe base.pointee._slots[Index<Element>(slot).retag()] = false
        return element
    }
    
    /// Moves and returns the last initialized element.
    ///
    /// This method maintains linear discipline: elements are removed
    /// from the end. The bit vector is updated automatically
    /// via `Storage.Inline.move(at:)`.
    ///
    /// ```swift
    /// var storage = Storage<Int>.Inline<8>()
    /// try storage.initialize.next(to: 1)
    /// try storage.initialize.next(to: 2)
    /// let last = try storage.move.last()  // Returns 2, count becomes 1
    /// ```
    ///
    /// - Returns: The moved element.
    /// - Throws: ``Storage/Error/empty`` if storage has no initialized elements.
    @inlinable
    @_lifetime(&self)
    public mutating func last<
        Element: ~Copyable,
        let capacity: Int
    >() throws(Storage<Element>.Error) -> Element
    where Tag == Storage<Element>.Move, Base == Storage<Element>.Inline<capacity> {
        let currentCount = unsafe base.pointee.initialization.count
        guard currentCount > .zero else { throw .empty }
        let slot = currentCount.subtract.saturating(.one).map(Ordinal.init)
        let bounded = Index<Element>.Bounded<capacity>(slot)!
        return self(at: bounded)
    }
}
