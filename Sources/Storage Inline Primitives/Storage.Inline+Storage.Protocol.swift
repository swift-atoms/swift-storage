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

public import Bit_Vector_Static_Primitives
public import Index_Primitives
public import Memory_Address_Primitives
public import Storage_Primitive
public import Storage_Protocol_Primitives

// MARK: - Storage.Protocol Witnesses (north-star typed-slot contract)

extension Storage.Inline where Element: ~Copyable {
    /// Reads or writes the initialized element at the given physical slot.
    ///
    /// Witnesses the `subscript(slot:)` requirement of `Storage.`Protocol``.
    ///
    /// The `_modify` accessor is `mutating` → it takes exclusive `&self`, so it
    /// derives its mutable pointer from `withUnsafeMutablePointer(to: &_storage)`
    /// (exclusive access), NOT from the non-mutating `withUnsafePointer`-derived
    /// `_mutablePointer(at:)`. This is the soundness that the value-backed
    /// north-star buys: no borrow-aliasing hazard, because the mutation flows
    /// through `&self` rather than a laundered borrow.
    ///
    /// - Parameter slot: The physical slot coordinate.
    /// - Returns: The element at the slot.
    /// - Precondition: The element at `slot` must be initialized and within capacity.
    @inlinable
    public subscript(slot: Index<Element>) -> Element {
        _read {
            // Read borrow via the package-level mutable pointer (unambiguous;
            // the public `pointer(at:)` overloads otherwise collide here).
            let pointer = unsafe _mutablePointer(at: slot)
            yield unsafe pointer.pointee
        }
        _modify {
            // Exclusive `&self` → derive the mutable pointer from the mutable
            // borrow of the inline `@_rawLayout` value. Sound for value-backed
            // storage (review §1[C3]).
            let pointer = unsafe withUnsafeMutablePointer(to: &_storage) { raw in
                unsafe UnsafeMutableRawPointer(raw)
                    .advanced(by: Index<Element>.Offset(fromZero: slot) * .stride)
                    .assumingMemoryBound(to: Element.self)
            }
            yield &(unsafe pointer.pointee)
        }
    }

    /// Initializes the uninitialized element at `slot` to `element`.
    ///
    /// Witnesses the `initialize(at:to:)` requirement of `Storage.`Protocol``.
    /// Promotes the existing `Storage.Inline+Initialize.swift` slot logic to the
    /// requirement signature and marks the slot initialized in the tracking
    /// bitvector. The write goes through the exclusive `&self` mutable pointer.
    ///
    /// - Parameters:
    ///   - slot: The physical slot coordinate.
    ///   - element: The value to store; ownership transfers to the storage.
    /// - Precondition: The element at `slot` must be uninitialized and within capacity.
    @inlinable
    public mutating func initialize(at slot: Index<Element>, to element: consuming Element) {
        // Derive the pointer first (exclusive `&_storage`), then initialize outside
        // the closure so `consume element` is not a closure-capture consume.
        let pointer = unsafe withUnsafeMutablePointer(to: &_storage) { raw in
            unsafe UnsafeMutableRawPointer(raw)
                .advanced(by: Index<Element>.Offset(fromZero: slot) * .stride)
                .assumingMemoryBound(to: Element.self)
        }
        unsafe pointer.initialize(to: consume element)
        _slots[slot.retag()] = true
    }

    /// Moves the initialized element out of `slot`, leaving it uninitialized.
    ///
    /// Witnesses the `move(at:)` requirement of `Storage.`Protocol``. Promotes the
    /// existing `Storage.Inline+Move.swift` slot logic to the requirement
    /// signature and clears the slot's tracking bit. The move goes through the
    /// exclusive `&self` mutable pointer.
    ///
    /// - Parameter slot: The physical slot coordinate.
    /// - Returns: The moved element; ownership transfers to the caller.
    /// - Precondition: The element at `slot` must be initialized and within capacity.
    @inlinable
    public mutating func move(at slot: Index<Element>) -> Element {
        let element = unsafe withUnsafeMutablePointer(to: &_storage) { raw in
            unsafe UnsafeMutableRawPointer(raw)
                .advanced(by: Index<Element>.Offset(fromZero: slot) * .stride)
                .assumingMemoryBound(to: Element.self)
                .move()
        }
        _slots[slot.retag()] = false
        return element
    }

    /// Returns a mutable pointer to the element at the given physical slot.
    ///
    /// A documented `@unsafe` escape hatch — NO LONGER a `Storage.`Protocol``
    /// requirement (the protocol member was removed; the surface is the typed
    /// `subscript`/`initialize`/`move`). The bounded overloads in
    /// `Storage.Inline ~Copyable.swift` carry a compile-time bound; this unbounded
    /// form is the shared escape-hatch entry point alongside `Storage.Contiguous<Memory.Heap<Element>>`.
    ///
    /// - Note: Retained for the `Buffer.{Ring,Linear}.Small._modify` heap-spill
    ///   sites (blocked by the ~Copyable-enum-payload mutation language limitation),
    ///   the `Buffer.Ring.Bounded.Walk` Escapable iterator, and the Heap/Inline
    ///   Property.View move/deinit route. REMOVE-WHEN those land on the typed surface.
    ///
    /// - Parameter slot: The physical slot coordinate.
    /// - Returns: A mutable pointer to the element.
    /// - Warning: The caller must ensure the slot is valid and within capacity.
    @unsafe
    @inlinable
    public func pointer(at slot: Index<Element>) -> UnsafeMutablePointer<Element> {
        unsafe _mutablePointer(at: slot)
    }
}

// MARK: - Storage.Protocol Conformance

extension Storage.Inline: Storage.`Protocol` where Element: ~Copyable {}
