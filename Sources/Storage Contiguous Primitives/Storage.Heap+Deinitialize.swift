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
public import Storage_Initialization_Primitives
public import Memory_Heap_Primitives
public import Storage_Primitive

// MARK: - Deinitialize Accessor

extension Storage.Contiguous where Element: ~Copyable, Substrate == Memory.Heap<Element> {
    /// Accessor for tracked deinitialize operations.
    ///
    /// Provides `.deinitialize.all()` for safe cleanup.
    ///
    /// ```swift
    /// heap.deinitialize.all()  // Deinitializes all elements, resets to empty
    /// ```
    ///
    /// - Note: For `~Copyable` elements the Heap is uniquely owned and never
    ///   value-copied, so this accessor mutates the backing buffer directly. The
    ///   `Element: Copyable` overload triggers copy-on-write first (see below).
    @inlinable
    public var `deinitialize`: Property<Storage.Deinitialize, Self>.Inout {
        mutating _read {
            yield Property<Storage.Deinitialize, Self>.Inout(&self)
        }
        mutating _modify {
            var accessor = Property<Storage.Deinitialize, Self>.Inout(&self)
            yield &accessor
        }
    }
}

extension Storage.Contiguous where Element: Copyable, Substrate == Memory.Heap<Element> {
    /// Copy-on-write accessor for tracked deinitialize operations.
    ///
    /// Triggers `ensureUnique()` before yielding the mutator so a value-copied
    /// Copyable Heap copies-on-write before any slot is deinitialized. Swift
    /// selects this more-constrained overload at concrete `Copyable`-element call
    /// sites; `~Copyable` Heaps use the direct overload above. This is the single
    /// choke point for deinitialize-path CoW.
    @inlinable
    public var `deinitialize`: Property<Storage.Deinitialize, Self>.Inout {
        mutating _read {
            ensureUnique()
            yield Property<Storage.Deinitialize, Self>.Inout(&self)
        }
        mutating _modify {
            ensureUnique()
            var accessor = Property<Storage.Deinitialize, Self>.Inout(&self)
            yield &accessor
        }
    }
}

// MARK: - Deinitialize Methods

extension Property.Inout where Base: ~Copyable {
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
    public mutating func all<Element: ~Copyable>()
    where Tag == Storage<Element>.Deinitialize, Base == Storage<Element>.Heap {
        base.value.initialization.forEach { range in
            guard !range.isEmpty else { return }
            unsafe base.value.pointer(at: range.lowerBound).deinitialize(count: range.count)
        }
        base.value.initialization = .empty
    }

    /// Deinitializes all elements in the given range.
    ///
    /// Uses bulk deinitialization for better performance on contiguous ranges.
    ///
    /// - Parameter range: The contiguous range of slots to deinitialize.
    /// - Precondition: All slots in the range must contain initialized elements.
    /// - Note: The caller is responsible for updating `initialization` state.
    @inlinable
    public mutating func callAsFunction<Element: ~Copyable>(
        range: Swift.Range<Index<Element>>
    ) where Tag == Storage<Element>.Deinitialize, Base == Storage<Element>.Heap {
        guard !range.isEmpty else { return }
        unsafe base.value.pointer(at: range.lowerBound).deinitialize(count: range.count)
    }

    /// Deinitializes the element at the given physical slot.
    ///
    /// - Parameter slot: The physical slot to deinitialize.
    /// - Precondition: The element at `slot` must be initialized.
    /// - Note: The caller is responsible for updating `initialization` state.
    @inlinable
    public mutating func callAsFunction<Element: ~Copyable>(
        at slot: Index<Element>
    ) where Tag == Storage<Element>.Deinitialize, Base == Storage<Element>.Heap {
        unsafe base.value.pointer(at: slot).deinitialize(count: .one)
    }
}
