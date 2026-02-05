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
internal import Standard_Library_Extensions

// MARK: - Factory

extension Storage.Heap where Element: ~Copyable {
    /// Creates storage with the specified minimum capacity.
    ///
    /// - Parameter minimumCapacity: The minimum number of slots to allocate.
    /// - Returns: A new storage instance with empty initialization.
    @inlinable
    public static func create(
        minimumCapacity: Index<Element>.Count
    ) -> Storage.Heap {
        unsafe unsafeDowncast(
            Storage.Heap.create(
                minimumCapacity: Int(bitPattern: minimumCapacity)
            ) { _ in Storage.Heap.Header() },
            to: Storage.Heap.self
        )
    }
}

// MARK: - Properties

extension Storage.Heap where Element: ~Copyable {
    /// The initialization state describing which slots are initialized.
    @inlinable
    public var initialization: Storage.Initialization {
        get { header.initialization }
        set { header.initialization = newValue }
    }

    /// Storage capacity in slot count.
    @inlinable
    public var slotCapacity: Index<Element>.Count {
        Index<Element>.Count(UInt(capacity))
    }
}

// MARK: - Fundamental Slot Access

extension Storage.Heap where Element: ~Copyable {
    /// Returns a mutable pointer to the element at the given physical slot.
    ///
    /// - Parameter slot: The physical slot coordinate.
    /// - Returns: A mutable pointer to the element.
    /// - Warning: The caller must ensure the slot is valid and within capacity.
    @unsafe
    @_lifetime(borrow self)
    @inlinable
    public func pointer(at slot: Index<Element>) -> UnsafeMutablePointer<Element> {
        unsafe withUnsafeMutablePointerToElements {
            let offset = Index<Element>.Offset(fromZero: slot)
            return unsafe $0 + offset
        }
    }

    /// Initializes storage at the given physical slot with the provided value.
    ///
    /// - Parameters:
    ///   - element: The value to store.
    ///   - slot: The physical slot to initialize.
    /// - Precondition: The element at `slot` must be uninitialized.
    /// - Note: The caller is responsible for updating `initialization` state.
    @inlinable
    public func initialize(to element: consuming Element, at slot: Index<Element>) {
        let ptr = unsafe pointer(at: slot)
        unsafe ptr.initialize(to: element)
    }

    /// Moves the element at the given physical slot, deinitializing that slot.
    ///
    /// - Parameter slot: The physical slot to move from.
    /// - Returns: The moved element.
    /// - Precondition: The element at `slot` must be initialized.
    /// - Note: The caller is responsible for updating `initialization` state.
    @inlinable
    public func move(at slot: Index<Element>) -> Element {
        unsafe pointer(at: slot).move()
    }

    /// Deinitializes the element at the given physical slot.
    ///
    /// - Parameter slot: The physical slot to deinitialize.
    /// - Precondition: The element at `slot` must be initialized.
    /// - Note: The caller is responsible for updating `initialization` state.
    @inlinable
    public func deinitialize(at slot: Index<Element>) {
        unsafe pointer(at: slot).deinitialize(count: 1)
    }
}

// MARK: - Span Operations

extension Storage.Heap where Element: ~Copyable {
    /// Deinitializes all elements in the given range.
    ///
    /// Uses bulk deinitialization for better performance on contiguous ranges.
    ///
    /// - Parameter range: The contiguous range of slots to deinitialize.
    /// - Precondition: All slots in the range must contain initialized elements.
    /// - Note: The caller is responsible for updating `initialization` state.
    @inlinable
    public func deinitialize(range: Swift.Range<Index<Element>>) {
        guard !range.isEmpty else { return }
        unsafe withUnsafeMutablePointerToElements { elements in
            let startOffset = Index<Element>.Offset(fromZero: range.lowerBound)
            unsafe (elements + startOffset).deinitialize(count: range.count)
        }
    }

    /// Deinitializes all tracked initialized slots and resets initialization to .empty.
    ///
    /// Iterates the `initialization` state and deinitializes exactly those slots
    /// that are tracked as initialized.
    @inlinable
    public func deinitialize() {
        switch header.initialization {
        case .empty:
            return
        case .one(let range):
            deinitialize(range: range)
        case .two(let first, let second):
            deinitialize(range: first)
            deinitialize(range: second)
        }
        header.initialization = .empty
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
    public func move(range: Swift.Range<Index<Element>>, to destination: Storage.Heap) {
        guard !range.isEmpty else { return }
        var srcSlot = range.lowerBound
        var dstSlot: Index<Element> = .zero
        while srcSlot < range.upperBound {
            destination.initialize(to: move(at: srcSlot), at: dstSlot)
            srcSlot = srcSlot.successor.saturating()
            dstSlot = dstSlot.successor.saturating()
        }
    }

}
