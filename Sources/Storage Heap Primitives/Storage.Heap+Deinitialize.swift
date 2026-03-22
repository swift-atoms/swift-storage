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

// MARK: - Deinitialize Accessor

extension Storage.Heap where Element: ~Copyable {
    /// Accessor for tracked deinitialize operations.
    ///
    /// Provides `.deinitialize.all()` for safe cleanup.
    ///
    /// ```swift
    /// heap.deinitialize.all()  // Deinitializes all elements, resets to empty
    /// ```
    @inlinable
    public var `deinitialize`: Property<Storage.Deinitialize, Storage.Heap> {
        Property(self)
    }
}

// MARK: - Deinitialize Methods

extension Property {
    /// Deinitializes all elements and resets to empty state.
    ///
    /// This method correctly handles all initialization patterns
    /// (`.empty`, `.linear`, `.one`, `.two`) and resets to `.empty`.
    ///
    /// ```swift
    /// var heap = Storage<Int>.Heap.create(minimumCapacity: 8)
    /// heap.initialize.next(to: 1)
    /// heap.initialize.next(to: 2)
    /// heap.deinitialize.all()  // Elements deinitialized, state is now .empty
    /// ```
    @inlinable
    public func all<Element: ~Copyable>()
    where Tag == Storage<Element>.Deinitialize, Base == Storage<Element>.Heap {
        base.header.initialization.forEach { range in
            guard !range.isEmpty else { return }
            unsafe base.pointer(at: range.lowerBound).deinitialize(count: range.count)
        }
        base.header.initialization = .empty
    }

    /// Deinitializes all elements in the given range.
    ///
    /// Uses bulk deinitialization for better performance on contiguous ranges.
    ///
    /// - Parameter range: The contiguous range of slots to deinitialize.
    /// - Precondition: All slots in the range must contain initialized elements.
    /// - Note: The caller is responsible for updating `initialization` state.
    @inlinable
    public func callAsFunction<Element: ~Copyable>(
        range: Swift.Range<Index<Element>>
    ) where Tag == Storage<Element>.Deinitialize, Base == Storage<Element>.Heap {
        guard !range.isEmpty else { return }
        unsafe base.pointer(at: range.lowerBound).deinitialize(count: range.count)
    }

    /// Deinitializes the element at the given physical slot.
    ///
    /// - Parameter slot: The physical slot to deinitialize.
    /// - Precondition: The element at `slot` must be initialized.
    /// - Note: The caller is responsible for updating `initialization` state.
    @inlinable
    public func callAsFunction<Element: ~Copyable>(
        at slot: Index<Element>
    ) where Tag == Storage<Element>.Deinitialize, Base == Storage<Element>.Heap {
        unsafe base.pointer(at: slot).deinitialize(count: .one)
    }
}
