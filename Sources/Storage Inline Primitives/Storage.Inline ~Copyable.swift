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
public import Bit_Vector_Primitives

// MARK: - Properties

// MARK: - Fundamental Slot Access

extension Storage.Inline where Element: ~Copyable {
    /// Returns an immutable pointer to the element at the given physical slot.
    ///
    /// Non-mutating: valid in `_read` accessors where `self` is borrowed.
    ///
    /// - Parameter slot: The physical slot coordinate.
    /// - Returns: An immutable pointer to the element.
    /// - Precondition: The element at `slot` must be initialized.
    @unsafe
    @_lifetime(borrow self)
    @inlinable
    public func pointer(at slot: Index<Element>) -> UnsafePointer<Element> {
        unsafe withUnsafePointer(to: _storage) { base in
            let raw = unsafe UnsafeRawPointer(base)
            return unsafe raw.advanced(by: Int(slot.rawValue.rawValue) * MemoryLayout<Element>.stride)
                .assumingMemoryBound(to: Element.self)
        }
    }

    /// Returns a mutable pointer to the element at the given physical slot.
    ///
    /// - Parameter slot: The physical slot coordinate.
    /// - Returns: A mutable pointer to the element.
    /// - Precondition: The element at `slot` must be initialized.
    @unsafe
    @_lifetime(&self)
    @inlinable
    @_disfavoredOverload
    public mutating func pointer(at slot: Index<Element>) -> UnsafeMutablePointer<Element> {
        unsafe withUnsafeMutablePointer(to: &_storage) { base in
            let raw = UnsafeMutableRawPointer(base)
            return unsafe raw.advanced(by: Int(slot.rawValue.rawValue) * MemoryLayout<Element>.stride)
                .assumingMemoryBound(to: Element.self)
        }
    }

    /// Initializes storage at the given physical slot with the provided value.
    ///
    /// - Parameters:
    ///   - element: The value to store.
    ///   - slot: The physical slot to initialize.
    /// - Precondition: The element at `slot` must be uninitialized.
    /// - Note: Automatically marks the slot as initialized in the tracking bit vector.
    @inlinable
    public mutating func initialize(to element: consuming Element, at slot: Index<Element>) {
        unsafe pointer(at: slot).initialize(to: element)
        _slots[Bit.Index(slot.rawValue)] = true
    }

    /// Moves the element at the given physical slot, deinitializing that slot.
    ///
    /// - Parameter slot: The physical slot to move from.
    /// - Returns: The moved element.
    /// - Precondition: The element at `slot` must be initialized.
    /// - Note: Automatically marks the slot as uninitialized in the tracking bit vector.
    @inlinable
    public mutating func move(at slot: Index<Element>) -> Element {
        let element = unsafe pointer(at: slot).move()
        _slots[Bit.Index(slot.rawValue)] = false
        return element
    }
}

// MARK: - Cross-Storage Operations

extension Storage.Inline where Element: ~Copyable {
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
    public mutating func move(range: Swift.Range<Index<Element>>, to destination: Storage<Element>.Heap) {
        guard !range.isEmpty else { return }
        unsafe destination.withUnsafeMutablePointerToElements { dst in
            var srcSlot = range.lowerBound
            var dstSlot: Index<Element> = .zero
            while srcSlot < range.upperBound {
                let dstOffset = Index<Element>.Offset(fromZero: dstSlot)
                unsafe (dst + dstOffset).initialize(to: self.pointer(at: srcSlot).move())
                _slots[Bit.Index(srcSlot.rawValue)] = false
                srcSlot = srcSlot.successor.saturating()
                dstSlot = dstSlot.successor.saturating()
            }
        }
    }
}
