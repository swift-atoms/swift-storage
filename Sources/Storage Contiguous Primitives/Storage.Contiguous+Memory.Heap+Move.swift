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

// MARK: - Move Accessor

extension Storage.Contiguous where Element: ~Copyable, Substrate == Memory.Heap<Element> {
    /// Accessor for tracked move operations.
    ///
    /// Provides `.move.last()` for linear discipline.
    ///
    /// ```swift
    /// let element = heap.move.last()  // Moves last element, updates state
    /// ```
    ///
    /// - Note: For `~Copyable` elements the Heap is uniquely owned and never
    ///   value-copied, so this accessor mutates the backing buffer directly. The
    ///   `Element: Copyable` overload triggers copy-on-write first (see below).
    @inlinable
    public var move: Property<Storage.Move, Self>.Inout {
        mutating _read {
            yield Property<Storage.Move, Self>.Inout(&self)
        }
        mutating _modify {
            var accessor = Property<Storage.Move, Self>.Inout(&self)
            yield &accessor
        }
    }
}

extension Storage.Contiguous where Element: Copyable, Substrate == Memory.Heap<Element> {
    /// Copy-on-write accessor for tracked move operations.
    ///
    /// Triggers `ensureUnique()` before yielding the mutator so a value-copied
    /// Copyable Heap copies-on-write before any element is moved out (a move
    /// deinitializes the source slot — a mutation). Swift selects this
    /// more-constrained overload at concrete `Copyable`-element call sites;
    /// `~Copyable` Heaps use the direct overload above. This is the single
    /// choke point for move-path CoW.
    @inlinable
    public var move: Property<Storage.Move, Self>.Inout {
        mutating _read {
            ensureUnique()
            yield Property<Storage.Move, Self>.Inout(&self)
        }
        mutating _modify {
            ensureUnique()
            var accessor = Property<Storage.Move, Self>.Inout(&self)
            yield &accessor
        }
    }
}

// MARK: - Move Methods

extension Property.Inout where Base: ~Copyable {
    /// Moves the element at the given physical slot, deinitializing that slot.
    ///
    /// - Parameter slot: The physical slot to move from.
    /// - Returns: The moved element.
    /// - Precondition: The element at `slot` must be initialized.
    /// - Note: The caller is responsible for updating `initialization` state.
    @inlinable
    public mutating func callAsFunction<Element: ~Copyable>(
        at slot: Index<Element>
    ) -> Element where Tag == Storage<Element>.Move, Base == Storage<Element>.Contiguous<Memory.Heap<Element>> {
        return unsafe base.value.pointer(at: slot).move()
    }

    /// Moves elements from a range to the destination storage starting at offset.
    ///
    /// Elements are moved from the source range and placed at slots
    /// offset..<(offset + range.count) in the destination storage.
    /// Source slots are deinitialized after moving.
    ///
    /// - Parameters:
    ///   - range: The contiguous range of slots to move from.
    ///   - destination: The destination storage to move elements into.
    ///   - offset: The destination slot to start writing at.
    /// - Precondition: All slots in the range must contain initialized elements.
    /// - Precondition: Destination slots offset..<(offset + range.count) must be uninitialized.
    /// - Note: The caller is responsible for updating `initialization` state on both storages.
    @inlinable
    public mutating func callAsFunction<Element: ~Copyable>(
        range: Swift.Range<Index<Element>>,
        to destination: borrowing Storage<Element>.Contiguous<Memory.Heap<Element>>,
        at offset: Index<Element>
    ) where Tag == Storage<Element>.Move, Base == Storage<Element>.Contiguous<Memory.Heap<Element>> {
        guard !range.isEmpty else { return }
        unsafe destination.pointer(at: offset)
            .move.initialize(from: base.value.pointer(at: range.lowerBound), count: range.count)
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
    public mutating func callAsFunction<Element: ~Copyable>(
        range: Swift.Range<Index<Element>>,
        to destination: borrowing Storage<Element>.Contiguous<Memory.Heap<Element>>
    ) where Tag == Storage<Element>.Move, Base == Storage<Element>.Contiguous<Memory.Heap<Element>> {
        self(range: range, to: destination, at: .zero)
    }

    /// Moves and returns the last initialized element.
    ///
    /// This method maintains linear discipline: elements are removed
    /// from the end. The initialization state is updated automatically.
    ///
    /// ```swift
    /// var heap = Storage<Int>.Contiguous<Memory.Heap<Int>>.create(minimumCapacity: 8)
    /// try heap.initialize.next(to: 1)
    /// try heap.initialize.next(to: 2)
    /// let last = try heap.move.last()  // Returns 2, count becomes 1
    /// ```
    ///
    /// - Returns: The moved element.
    /// - Throws: ``Storage/Error/empty`` if storage has no initialized elements.
    @inlinable
    public mutating func last<Element: ~Copyable>() throws(Storage<Element>.Error) -> Element
    where Tag == Storage<Element>.Move, Base == Storage<Element>.Contiguous<Memory.Heap<Element>> {
        let currentCount = base.value.initialization.count
        guard currentCount > .zero else { throw .empty }
        let newCount = currentCount.subtract.saturating(.one)
        let element = self(at: newCount.map(Ordinal.init))
        base.value.initialization = .linear(count: newCount)
        return element
    }
}
