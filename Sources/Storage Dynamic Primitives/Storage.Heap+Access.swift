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

// MARK: - Initialization State

extension Storage.Heap where Element: ~Copyable {
    /// The initialization state describing which slots are initialized.
    @inlinable
    public var initialization: Storage.Initialization {
        get { header.initialization }
        set { header.initialization = newValue }
    }

    /// Storage capacity in slot terms.
    @inlinable
    public var slotCapacity: Storage.Slot.Count {
        Storage.Slot.Count(UInt(capacity))
    }
}

// MARK: - Fundamental Element Access (Slot-Based)

extension Storage.Heap where Element: ~Copyable {
    /// Returns a mutable pointer to the element at the given physical slot.
    ///
    /// - Parameter slot: The physical slot coordinate.
    /// - Returns: A mutable pointer to the element.
    /// - Warning: The caller must ensure the slot is valid and within capacity.
    @inlinable
    @unsafe
    public func pointer(at slot: Storage.Slot) -> UnsafeMutablePointer<Element> {
        unsafe withUnsafeMutablePointerToElements {
            let offset = Int(bitPattern: slot.rawValue.rawValue)
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
    public func initialize(to element: consuming Element, at slot: Storage.Slot) {
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
    public func move(at slot: Storage.Slot) -> Element {
        unsafe pointer(at: slot).move()
    }

    /// Deinitializes the element at the given physical slot.
    ///
    /// - Parameter slot: The physical slot to deinitialize.
    /// - Precondition: The element at `slot` must be initialized.
    /// - Note: The caller is responsible for updating `initialization` state.
    @inlinable
    public func deinitialize(at slot: Storage.Slot) {
        unsafe pointer(at: slot).deinitialize(count: 1)
    }
}

// MARK: - Span-Based Operations

extension Storage.Heap where Element: ~Copyable {
    /// Deinitializes all elements in the given span.
    ///
    /// Iterates through all slots in the span and deinitializes each element.
    ///
    /// - Parameter span: The contiguous range of slots to deinitialize.
    /// - Precondition: All slots in the span must contain initialized elements.
    /// - Note: The caller is responsible for updating `initialization` state.
    @inlinable
    public func deinitialize(span: Storage.Span) {
        guard !span.isEmpty else { return }
        _ = unsafe withUnsafeMutablePointerToElements { elements in
            var slot = span.start
            while slot < span.end {
                let offset = Int(bitPattern: slot.rawValue.rawValue)
                unsafe (elements + offset).deinitialize(count: 1)
                slot = slot.successor.saturating()
            }
        }
    }

    /// Moves elements from a span to linear positions in the destination storage.
    ///
    /// Elements are moved from the source span and placed at slots 0..<span.count
    /// in the destination storage. Source slots are deinitialized after moving.
    ///
    /// - Parameters:
    ///   - span: The contiguous range of slots to move from.
    ///   - destination: The destination storage to move elements into.
    /// - Precondition: All slots in the span must contain initialized elements.
    /// - Precondition: Destination slots 0..<span.count must be uninitialized.
    /// - Note: The caller is responsible for updating `initialization` state on both storages.
    @inlinable
    public func move(span: Storage.Span, to destination: Storage.Heap<Element>) {
        guard !span.isEmpty else { return }
        _ = unsafe withUnsafeMutablePointerToElements { srcElements in
            unsafe destination.withUnsafeMutablePointerToElements { dstElements in
                var srcSlot = span.start
                var dstOffset = 0
                while srcSlot < span.end {
                    let srcOffset = Int(bitPattern: srcSlot.rawValue.rawValue)
                    unsafe (dstElements + dstOffset).initialize(
                        to: (srcElements + srcOffset).move()
                    )
                    srcSlot = srcSlot.successor.saturating()
                    dstOffset += 1
                }
            }
        }
    }
}

// MARK: - Span Access

extension Storage.Heap where Element: ~Copyable {
    /// Provides read-only span access to elements in the specified slot range.
    ///
    /// The span is valid only for the duration of the closure.
    ///
    /// - Parameters:
    ///   - span: The contiguous range of slots to access.
    ///   - body: A closure that receives the span.
    /// - Returns: The value returned by the closure.
    /// - Throws: Rethrows any error thrown by the closure.
    /// - Precondition: Elements in the span range must be initialized.
    @inlinable
    public func withSpan<R, E: Swift.Error>(
        _ span: Storage.Span,
        _ body: (Span<Element>) throws(E) -> R
    ) throws(E) -> R {
        var thrown: E? = nil
        let result: R? = unsafe withUnsafeMutablePointerToElements { base in
            let startOffset = Int(bitPattern: span.start.rawValue.rawValue)
            let count = Int(bitPattern: span.count)
            let spanView = unsafe Span(
                _unsafeStart: UnsafePointer(base + startOffset),
                count: count
            )
            do {
                return try body(spanView)
            } catch let e as E {
                thrown = e
                return nil
            } catch {
                preconditionFailure("unexpected error type")
            }
        }
        if let thrown { throw thrown }
        return result!
    }
}
