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

// MARK: - Properties

extension Storage.Inline where Element: ~Copyable {
    /// The initialization state tracking which slots are initialized.
    @inlinable
    public var initialization: Storage.Initialization {
        get { _initialization }
        set { _initialization = newValue }
    }
}

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
    public func pointer(at slot: Storage.Slot) -> UnsafePointer<Element> {
        unsafe withUnsafePointer(to: _storage) { base in
            return unsafe UnsafeRawPointer(base)
                .advanced(by: (Storage.Slot.Offset(fromZero: slot) * .stride).rawValue.rawValue)
                .assumingMemoryBound(to: Element.self)
        }
    }

    /// Returns a mutable pointer to the element at the given physical slot.
    ///
    /// - Parameter slot: The physical slot coordinate.
    /// - Returns: A mutable pointer to the element.
    /// - Precondition: The element at `slot` must be initialized.
    @inlinable
    @_disfavoredOverload
    public mutating func pointer(at slot: Storage.Slot) -> UnsafeMutablePointer<Element> {
        unsafe withUnsafeMutablePointer(to: &_storage) { base in
            return unsafe UnsafeMutableRawPointer(base)
                .advanced(by: (Storage.Slot.Offset(fromZero: slot) * .stride).rawValue.rawValue)
                .assumingMemoryBound(to: Element.self)
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
    public mutating func initialize(to element: consuming Element, at slot: Storage.Slot) {
        unsafe pointer(at: slot).initialize(to: element)
    }

    /// Moves the element at the given physical slot, deinitializing that slot.
    ///
    /// - Parameter slot: The physical slot to move from.
    /// - Returns: The moved element.
    /// - Precondition: The element at `slot` must be initialized.
    /// - Note: The caller is responsible for updating `initialization` state.
    @inlinable
    public mutating func move(at slot: Storage.Slot) -> Element {
        unsafe pointer(at: slot).move()
    }
}

// MARK: - Deinitialization

extension Storage.Inline where Element: ~Copyable {
    /// Deinitializes the element at the given physical slot.
    ///
    /// - Parameter slot: The physical slot to deinitialize.
    /// - Precondition: The element at `slot` must be initialized.
    /// - Note: Non-mutating to allow use from deinit-like contexts.
    /// - Note: The caller is responsible for updating `initialization` state.
    @inlinable
    public func deinitialize(at slot: Storage.Slot) {
        _ = unsafe withUnsafePointer(to: _storage) { base in
            unsafe UnsafeMutableRawPointer(mutating: base)
                .advanced(by: (Storage.Slot.Offset(fromZero: slot) * .stride).rawValue.rawValue)
                .assumingMemoryBound(to: Element.self)
                .deinitialize(count: 1)
        }
    }

    /// Deinitializes all elements in the given span.
    ///
    /// - Parameter span: The contiguous range of slots to deinitialize.
    /// - Precondition: All slots in the span must contain initialized elements.
    /// - Note: Non-mutating to allow use from deinit-like contexts.
    /// - Note: The caller is responsible for updating `initialization` state.
    @inlinable
    public func deinitialize(span: Storage.Span) {
        guard !span.isEmpty else { return }
        var slot = span.start
        while slot < span.end {
            deinitialize(at: slot)
            slot = slot.successor.saturating()
        }
    }

    /// Deinitializes all tracked initialized slots and resets initialization to .empty.
    ///
    /// Iterates the `initialization` state and deinitializes exactly those slots
    /// that are tracked as initialized.
    @inlinable
    public mutating func deinitialize() {
        switch _initialization {
        case .empty:
            return
        case .one(let span):
            deinitialize(span: span)
        case .two(let first, let second):
            deinitialize(span: first)
            deinitialize(span: second)
        }
        _initialization = .empty
    }
}

// MARK: - Cross-Storage Operations

extension Storage.Inline where Element: ~Copyable {
    /// Moves elements in span to linear positions in destination heap storage.
    ///
    /// Elements from the source span are placed at slots 0..<span.count in the
    /// destination storage. Source slots are deinitialized after moving.
    ///
    /// - Parameters:
    ///   - span: The contiguous range of slots to move from.
    ///   - destination: The destination heap storage.
    /// - Precondition: All slots in the span must contain initialized elements.
    /// - Precondition: Destination slots 0..<span.count must be uninitialized.
    /// - Note: The caller is responsible for updating `initialization` state on both storages.
    @inlinable
    public mutating func move(span: Storage.Span, to destination: Storage.Heap<Element>) {
        guard !span.isEmpty else { return }
        unsafe destination.withUnsafeMutablePointerToElements { dst in
            var srcSlot = span.start
            var dstSlot: Storage.Slot = .zero
            while srcSlot < span.end {
                let dstOffset = Storage.Slot.Offset(fromZero: dstSlot).retag(Element.self)
                unsafe (dst + dstOffset).initialize(to: self.pointer(at: srcSlot).move())
                srcSlot = srcSlot.successor.saturating()
                dstSlot = dstSlot.successor.saturating()
            }
        }
    }
}
