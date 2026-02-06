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

// MARK: - Move Accessor

extension Storage.Heap where Element: ~Copyable {
    /// Accessor for tracked move operations.
    ///
    /// Provides `.move.last()` for linear discipline.
    ///
    /// ```swift
    /// let element = heap.move.last()  // Moves last element, updates state
    /// ```
    @inlinable
    public var move: Property<Storage.Move, Storage.Heap> {
        Property(self)
    }
}

// MARK: - Move Methods

extension Property {
    /// Moves the element at the given physical slot, deinitializing that slot.
    ///
    /// - Parameter slot: The physical slot to move from.
    /// - Returns: The moved element.
    /// - Precondition: The element at `slot` must be initialized.
    /// - Note: The caller is responsible for updating `initialization` state.
    @inlinable
    public func callAsFunction<Element: ~Copyable>(
        at slot: Index<Element>
    ) -> Element where Tag == Storage<Element>.Move, Base == Storage<Element>.Heap {
        return unsafe base.pointer(at: slot).move()
    }
    
    /// Moves elements from a range to linear positions in the destination storage.
    ///
    /// Elements are moved from the source range and placed at slots 0..<range.count
    /// in the destination storage. Source slots are deinitialized after moving.
    ///
    /// - Parameters:
    ///   - range: The contiguous range of slots to move from.
    ///   - destination: The destination storage to move elements into.
    /// - Precondition: All slots in the range must contain initialized elements.
    /// - Precondition: Destination slots 0..<range.count must be uninitialized.
    /// - Note: The caller is responsible for updating `initialization` state on both storages.
    @inlinable
    public func callAsFunction<Element: ~Copyable>(
        range: Swift.Range<Index<Element>>,
        to destination: Storage<Element>.Heap
    ) where Tag == Storage<Element>.Move, Base == Storage<Element>.Heap {
        guard !range.isEmpty else { return }
        var srcSlot = range.lowerBound
        var dstSlot: Index<Element> = .zero
        while srcSlot < range.upperBound {
            destination.initialize(to: base.move(at: srcSlot), at: dstSlot)
            srcSlot = srcSlot.successor.saturating()
            dstSlot = dstSlot.successor.saturating()
        }
    }
    
    /// Moves and returns the last initialized element.
    ///
    /// This method maintains linear discipline: elements are removed
    /// from the end. The initialization state is updated automatically.
    ///
    /// ```swift
    /// var heap = Storage<Int>.Heap.create(minimumCapacity: 8)
    /// try heap.initialize.next(to: 1)
    /// try heap.initialize.next(to: 2)
    /// let last = try heap.move.last()  // Returns 2, count becomes 1
    /// ```
    ///
    /// - Returns: The moved element.
    /// - Throws: ``Storage/Error/empty`` if storage has no initialized elements.
    @inlinable
    public func last<Element: ~Copyable>() throws(Storage<Element>.Error) -> Element
    where Tag == Storage<Element>.Move, Base == Storage<Element>.Heap {
        let currentCount = base.initialization.count
        guard currentCount > .zero else { throw .empty }
        let newCount = currentCount.subtract.saturating(.one)
        let element = base.move(at: newCount.map(Ordinal.init))
        base.initialization = .linear(count: newCount)
        return element
    }
}

