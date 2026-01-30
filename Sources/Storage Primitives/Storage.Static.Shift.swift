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

public import Property_Primitives

// MARK: - Shift Property Accessor

extension Storage.Static where Element: ~Copyable {
    /// Property view for shift operations.
    ///
    /// Provides `.shift.left(removedAt:count:)` for filling gaps after element removal.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // After removing element at index 1:
    /// let removed = storage.move(at: Index(1))
    /// storage.shift.left(removedAt: Index(1), count: Index.Count(4))
    /// // Elements shifted: [A, C, D, _] (caller updates count to 3)
    /// ```
    @inlinable
    public var shift: Property<Shift, Self>.View.Typed<Element>.Valued<capacity> {
        mutating _read {
            yield unsafe Property<Shift, Self>.View.Typed<Element>.Valued<capacity>(&self)
        }
        mutating _modify {
            var view = unsafe Property<Shift, Self>.View.Typed<Element>.Valued<capacity>(&self)
            yield &view
        }
    }
}

// MARK: - Shift Left Operation

extension Property.View.Typed.Valued
where Tag == Shift, Base == Storage<Element>.Static<n>, Element: ~Copyable {
    /// Shifts elements left to fill a gap at the removed index.
    ///
    /// Moves elements from `[removedAt+1, count)` to `[removedAt, count-1)`.
    /// The caller is responsible for updating any external count tracking.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Before: [A, B, C, D] count=4, remove at index 1
    /// let removed = storage.move(at: Index(1))
    /// storage.shift.left(removedAt: Index(1), count: Index.Count(4))
    /// // After:  [A, C, D, _] (caller decrements count to 3)
    /// ```
    ///
    /// - Parameters:
    ///   - index: The index where an element was removed.
    ///   - count: The count before removal (number of initialized elements).
    /// - Precondition: `index` must be less than `count`.
    /// - Precondition: The element at `index` must already be deinitialized.
    @_lifetime(&self)
    @inlinable
    public mutating func left(removedAt index: Index<Element>, count: Index<Element>.Count) {
        let newCount = count.subtract.saturating(.one)

        // If removing the last element, nothing to shift
        guard index < newCount else { return }

        // Shift elements left: move [index+1, count) to [index, count-1)
        unsafe withUnsafeMutablePointer(to: &base.pointee._storage) { storagePtr in
            let address = unsafe Memory.Mutable.Address(storagePtr)
            (index..<newCount).forEach { destIndex in
                let srcIndex = destIndex + .one
                let srcPtr: Pointer<Element>.Mutable = address.pointer(
                    at: srcIndex,
                    stride: Storage<Element>.Static<n>.slotStride,
                    as: Element.self
                )
                let dstPtr: Pointer<Element>.Mutable = address.pointer(
                    at: destIndex,
                    stride: Storage<Element>.Static<n>.slotStride,
                    as: Element.self
                )
                dstPtr.initialize(to: srcPtr.move())
            }
        }
    }
}
