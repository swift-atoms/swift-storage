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

// MARK: - Initialization Property

extension Storage.Static where Element: ~Copyable {
    /// The initialization state tracking which slots are initialized.
    ///
    /// Storage uses this to correctly deinitialize only initialized slots
    /// when `deinitializeAll()` is called.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// var storage = try Storage.Static<Int, 8>()
    /// storage.initialize(to: 42, at: .zero)
    /// storage.initialization = .linear(count: Storage.Slot.Count(1))
    /// // Later:
    /// storage.deinitializeAll()  // Uses initialization to clean up
    /// ```
    @inlinable
    public var initialization: Storage.Initialization {
        get { _initialization }
        set { _initialization = newValue }
    }
}

// MARK: - Slot-Based Access

extension Storage.Static where Element: ~Copyable {
    /// Returns a mutable pointer to the element at the given physical slot.
    ///
    /// - Parameter slot: The physical slot coordinate.
    /// - Returns: A mutable pointer to the element.
    /// - Precondition: The element at `slot` must be initialized.
    @inlinable
    @_disfavoredOverload
    public mutating func pointer(at slot: Storage.Slot) -> UnsafeMutablePointer<Element> {
        unsafe withUnsafeMutablePointer(to: &_storage) { base in
            let byteOffset = Int(slot.rawValue.rawValue) * Self.slotStride
            return unsafe UnsafeMutableRawPointer(base)
                .advanced(by: byteOffset)
                .assumingMemoryBound(to: Element.self)
        }
    }

    /// Returns an immutable pointer to the element at the given physical slot (non-mutating).
    ///
    /// This overload is non-mutating, enabling use in `_read` accessors where
    /// `self` is borrowed immutably.
    ///
    /// - Parameter slot: The physical slot coordinate.
    /// - Returns: An immutable pointer to the element.
    /// - Precondition: The element at `slot` must be initialized.
    @unsafe
    @_lifetime(borrow self)
    @inlinable
    @_disfavoredOverload
    public func pointer(at slot: Storage.Slot) -> UnsafePointer<Element> {
        unsafe withUnsafePointer(to: _storage) { base in
            let byteOffset = Int(slot.rawValue.rawValue) * Self.slotStride
            return unsafe UnsafeRawPointer(base)
                .advanced(by: byteOffset)
                .assumingMemoryBound(to: Element.self)
        }
    }

    /// Initializes storage at the given physical slot with the provided value.
    ///
    /// - Parameters:
    ///   - element: The value to store.
    ///   - slot: The physical slot to initialize.
    /// - Precondition: The element at `slot` must be uninitialized.
    @inlinable
    @_disfavoredOverload
    public mutating func initialize(to element: consuming Element, at slot: Storage.Slot) {
        unsafe pointer(at: slot).initialize(to: element)
    }

    /// Moves the element at the given physical slot, deinitializing that slot.
    ///
    /// - Parameter slot: The physical slot to move from.
    /// - Returns: The moved element.
    /// - Precondition: The element at `slot` must be initialized.
    @inlinable
    @_disfavoredOverload
    public mutating func move(at slot: Storage.Slot) -> Element {
        unsafe pointer(at: slot).move()
    }
}

// MARK: - Initialization-Aware Deinitialization

extension Storage.Static where Element: ~Copyable {
    /// Deinitializes all initialized elements using the tracked initialization state.
    ///
    /// This method iterates over the spans in `initialization` and deinitializes
    /// exactly those slots, then sets initialization to `.empty`.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// var storage = try Storage.Static<Int, 8>()
    /// // ... initialize elements ...
    /// storage.initialization = .linear(count: Storage.Slot.Count(4))
    /// // Later:
    /// storage.deinitializeAll()
    /// ```
    @inlinable
    public mutating func deinitializeAll() {
        switch _initialization {
        case .empty:
            return
        case .one(let span):
            _deinitializeSpan(span)
        case .two(let first, let second):
            _deinitializeSpan(first)
            _deinitializeSpan(second)
        }
        _initialization = .empty
    }

    @usableFromInline
    internal mutating func _deinitializeSpan(_ span: Storage.Span) {
        guard !span.isEmpty else { return }
        var slot = span.start
        while slot < span.end {
            unsafe pointer(at: slot).deinitialize(count: 1)
            slot = slot.successor.saturating()
        }
    }
}
