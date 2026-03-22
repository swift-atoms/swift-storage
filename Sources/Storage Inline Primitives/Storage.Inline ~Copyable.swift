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
internal import Bit_Vector_Primitives
public import Vector_Primitives_Core
internal import Vector_Primitives

// MARK: - Pointer Access

extension Storage.Inline where Element: ~Copyable {
    /// Returns a mutable pointer to the element at the given bounded physical slot.
    ///
    /// Precondition-free — the bounded index guarantees validity.
    ///
    /// - Parameter slot: A bounded physical slot coordinate.
    /// - Returns: A mutable pointer to the element.
    @unsafe
    @_lifetime(borrow self)
    @inlinable
    public func pointer(at slot: Index<Element>.Bounded<capacity>) -> UnsafeMutablePointer<Element> {
        unsafe _mutablePointer(at: Index<Element>(slot))
    }

    /// Returns an immutable pointer to the element at the given bounded physical slot.
    ///
    /// Precondition-free — the bounded index guarantees validity.
    ///
    /// - Parameter slot: A bounded physical slot coordinate.
    /// - Returns: An immutable pointer to the element.
    @unsafe
    @_lifetime(borrow self)
    @inlinable
    @_disfavoredOverload
    public func pointer(at slot: Index<Element>.Bounded<capacity>) -> UnsafePointer<Element> {
        unsafe pointer(at: Index<Element>(slot))
    }

    /// Returns an immutable pointer to the element at the given physical slot.
    ///
    /// This is the primitive address computation for inline storage.
    /// All other slot access methods delegate to this.
    ///
    /// - Parameter slot: The physical slot coordinate.
    /// - Returns: An immutable pointer to the element.
    /// - Precondition: The element at `slot` must be initialized.
    @unsafe
    @_lifetime(borrow self)
    @inlinable
    package func pointer(at slot: Index<Element>) -> UnsafePointer<Element> {
        unsafe withUnsafePointer(to: _storage) { base in
            unsafe UnsafeRawPointer(base)
                .advanced(by: Index<Element>.Offset(fromZero: slot) * .stride)
                .assumingMemoryBound(to: Element.self)
        }
    }

    /// Returns a mutable pointer to the element at the given physical slot.
    ///
    /// Encapsulates the `UnsafeMutablePointer(mutating:)` cast in one place.
    /// All mutable slot access methods delegate to this.
    ///
    /// - Parameter slot: The physical slot coordinate.
    /// - Returns: A mutable pointer to the element.
    /// - Precondition: The element at `slot` must be initialized.
    @unsafe
    @_lifetime(borrow self)
    @inlinable
    package func _mutablePointer(at slot: Index<Element>) -> UnsafeMutablePointer<Element> {
        unsafe UnsafeMutablePointer(mutating: pointer(at: slot))
    }
}

// MARK: - Properties

extension Storage.Inline where Element: ~Copyable {
    /// Storage capacity in slot count.
    ///
    /// This is a runtime-accessible view of the compile-time `capacity` parameter.
    /// Matches `Storage.Heap.slotCapacity` for API parity.
    @inlinable
    public var slotCapacity: Index<Element>.Count {
        try! Index<Element>.Count(capacity)
    }

    /// Initialization state derived from the bit vector.
    ///
    /// The getter assumes linear initialization discipline (contiguous from slot 0).
    /// It returns `.linear(count: popcount)` where `popcount` is the number of
    /// set bits. This is correct when all initialized slots form a contiguous
    /// range starting at zero.
    ///
    /// For sparse or ring buffer patterns set via the setter, the getter is
    /// lossy — it reports the total count but not the actual slot positions.
    /// For per-slot tracking in those cases, inspect `_slots` directly.
    ///
    /// The setter correctly handles all patterns (`.empty`, `.one`, `.two`)
    /// by updating the bit vector ranges. This allows buffer-primitives to
    /// sync header state with storage via
    /// `storage.initialization = header.initialization`.
    @inlinable
    public var initialization: Storage.Initialization {
        get {
            if _slots.isEmpty {
                return .empty
            }
            // For linear patterns, compute the range from 0 to count
            return .linear(count: _slots.popcount.retag(Element.self))
        }
        set {
            _slots.clear.all()
            newValue.forEach { range in
                guard !range.isEmpty else { return }
                _slots.set.range(range.map.bounds { $0.retag(Bit.self) })
            }
        }
    }
}

// MARK: - Sendable

// @_rawLayout types require @unchecked Sendable
extension Storage.Inline._Raw: @unchecked Sendable where Element: Sendable {}

/// `Storage.Inline` is `Sendable` when its elements are `Sendable`.
/// Requires @unchecked because _Raw uses @unchecked Sendable.
extension Storage.Inline: @unchecked Sendable where Element: Sendable {}

