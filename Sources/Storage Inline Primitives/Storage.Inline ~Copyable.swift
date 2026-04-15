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
public import Bit_Vector_Static_Primitives
public import Vector_Primitives_Core
internal import Vector_Primitives
public import Memory_Primitives_Standard_Library_Integration

// MARK: - Pointer Access

extension Storage.Inline where Element: ~Copyable {
    /// Returns a mutable pointer to the element at the given bounded physical slot.
    ///
    /// Precondition-free — the bounded index guarantees validity.
    ///
    /// - Parameter slot: A bounded physical slot coordinate.
    /// - Returns: A mutable pointer to the element.
    @unsafe
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

// WHY: Category D — structural Sendable workaround (SP-2).
// WHY: `Storage.Inline._Raw` is a @_rawLayout wrapper whose sole purpose is
// WHY: layout computation. @_rawLayout blocks structural Sendable inference.
// WHY: No caller invariant — the raw bytes simply contain Elements.
// WHEN TO REMOVE: When compiler gains structural Sendable inference through
// WHEN TO REMOVE: @_rawLayout types.
// TRACKING: unsafe-audit-findings.md Category D SP-2.
extension Storage.Inline._Raw: @unchecked Sendable where Element: Sendable {}

/// Sendable conformance for `Storage.Inline`.
///
/// ## Safety Invariant
///
/// `~Copyable` guarantees single ownership: the value lives in exactly one
/// stack slot at a time, and transfer across threads is a move. The inline
/// `@_rawLayout` buffer and its slot-tracking bitvector travel together as
/// one unit.
///
/// ## Intended Use
///
/// - Moving a fixed-capacity inline buffer from a producer thread to a
///   consumer thread as a one-shot transfer.
/// - Storing inside a larger `~Copyable` / `Sendable` container that is
///   itself ownership-transferred.
///
/// ## Non-Goals
///
/// Does NOT support concurrent access. Ownership is single-owner; transfer
/// is one-shot.
extension Storage.Inline: @unsafe @unchecked Sendable where Element: Sendable {}

