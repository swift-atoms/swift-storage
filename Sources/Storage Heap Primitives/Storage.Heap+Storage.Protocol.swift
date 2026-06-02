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

import Affine_Primitives_Standard_Library_Integration
public import Index_Primitives
public import Storage_Primitive
public import Storage_Protocol_Primitives

// MARK: - Storage.Protocol Witnesses (north-star typed-slot contract)

extension Storage.Heap where Element: ~Copyable {
    /// Reads or writes the initialized element at the given physical slot.
    ///
    /// Witnesses the `subscript(slot:)` requirement of `Storage.`Protocol``. The
    /// accessors reach the `ManagedBuffer` tail element DIRECTLY via
    /// `withUnsafeMutablePointerToElements` rather than routing through the retained
    /// `pointer(at:)` escape hatch, keeping the witness independent of it. `_modify`
    /// is `mutating` → exclusive `&self`.
    ///
    /// - Parameter slot: The physical slot coordinate.
    /// - Returns: The element at the slot.
    /// - Precondition: The element at `slot` must be initialized and within capacity.
    @inlinable
    public subscript(slot: Index<Element>) -> Element {
        _read {
            // Derive the tail-element pointer first (the established
            // `Storage.Heap+pointer.swift` pattern), then borrow `.pointee`
            // through the yield. Accessing `.pointee` *inside* the closure would
            // consume the borrowed ~Copyable element.
            let pointer = unsafe _buffer.withUnsafeMutablePointerToElements {
                unsafe $0 + Index<Element>.Offset(fromZero: slot)
            }
            yield unsafe pointer.pointee
        }
        _modify {
            // The element pointer is stable across the yield because the backing
            // buffer is a class allocation; the mutating accessor's exclusive
            // `&self` access keeps it sound.
            let pointer = unsafe _buffer.withUnsafeMutablePointerToElements {
                unsafe $0 + Index<Element>.Offset(fromZero: slot)
            }
            yield &(unsafe pointer.pointee)
        }
    }

    /// Initializes the uninitialized element at `slot` to `element`.
    ///
    /// Witnesses the `initialize(at:to:)` requirement of `Storage.`Protocol``.
    /// Promotes the existing `Storage.Heap+Initialize.swift` slot logic to the
    /// requirement signature, addressing the tail element directly.
    ///
    /// - Parameters:
    ///   - slot: The physical slot coordinate.
    ///   - element: The value to store; ownership transfers to the storage.
    /// - Precondition: The element at `slot` must be uninitialized and within capacity.
    @inlinable
    public mutating func initialize(at slot: Index<Element>, to element: consuming Element) {
        // Derive the pointer first so the `consume element` does not happen inside
        // the closure capture (which would demand reinitialization).
        let pointer = unsafe _buffer.withUnsafeMutablePointerToElements {
            unsafe $0 + Index<Element>.Offset(fromZero: slot)
        }
        unsafe pointer.initialize(to: consume element)
    }

    /// Moves the initialized element out of `slot`, leaving it uninitialized.
    ///
    /// Witnesses the `move(at:)` requirement of `Storage.`Protocol``. Promotes the
    /// existing `Storage.Heap+Move.swift` slot logic to the requirement signature,
    /// addressing the tail element directly.
    ///
    /// - Parameter slot: The physical slot coordinate.
    /// - Returns: The moved element; ownership transfers to the caller.
    /// - Precondition: The element at `slot` must be initialized and within capacity.
    @inlinable
    public mutating func move(at slot: Index<Element>) -> Element {
        let pointer = unsafe _buffer.withUnsafeMutablePointerToElements {
            unsafe $0 + Index<Element>.Offset(fromZero: slot)
        }
        return unsafe pointer.move()
    }
}

// MARK: - Storage.Protocol Conformance

// The remaining `capacity` witness is a natural-named member already on the façade
// (`capacity: Index<Element>.Count`, Storage.Heap ~Copyable.swift). The façade
// exposes no `ManagedBuffer.capacity: Int` because the backing `_buffer` is internal
// — the structural payoff of the value-type façade (Opt A): the
// `Int`/`Index<Element>.Count` capacity collision that blocked conforming the class
// is gone.
//
// `Storage.Heap` also retains a concrete `@unsafe func pointer(at:)`
// (Storage.Heap+pointer.swift) — a documented escape hatch, NOT a `Storage.`Protocol``
// requirement — for the Small._modify / Bounded.Walk / Property.View sites.
extension Storage.Heap: Storage.`Protocol` where Element: ~Copyable {}
