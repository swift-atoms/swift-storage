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
public import Store_Protocol_Primitives
public import Store_Initialization_Primitives
import Affine_Primitives_Standard_Library_Integration
import Ordinal_Primitives_Standard_Library_Integration

// MARK: - In-place base (per-op, never cached — the inline bytes move with the value)

extension Store.Inline {
    /// The typed base for reading — recomputed within the caller's borrow of `self`; never cached.
    @inlinable
    internal func _readBase() -> UnsafePointer<Element> {
        unsafe withUnsafePointer(to: _storage) {
            unsafe UnsafeRawPointer($0).assumingMemoryBound(to: Element.self)
        }
    }

    /// The typed base for mutation — recomputed within the caller's exclusive `&self` access.
    @inlinable
    internal mutating func _mutableBase() -> UnsafeMutablePointer<Element> {
        unsafe withUnsafeMutablePointer(to: &_storage) {
            unsafe UnsafeMutableRawPointer($0).assumingMemoryBound(to: Element.self)
        }
    }
}

// MARK: - Properties

extension Store.Inline {
    /// Fixed inline capacity — the value-generic `n`.
    @inlinable
    public var capacity: Index<Element>.Count { Index<Element>.Count(UInt(n)) }

    /// Live occupancy — the ledger's initialized count.
    @inlinable
    public var count: Index<Element>.Count { _initialization.count }

    /// Whether no slots are initialized.
    @inlinable
    public var isEmpty: Bool { _initialization.isEmpty }

    /// The initialization ledger — settable so a composing discipline can bulk-sync it.
    @inlinable
    public var initialization: Store.Initialization<Element> {
        get { _initialization }
        set { _initialization = newValue }
    }
}

// MARK: - Store.Protocol seam (the 4 ops, over the in-place inline bytes)

extension Store.Inline {
    /// Reads or writes the initialized element at a physical slot (witnesses `subscript`).
    @inlinable
    public subscript(slot: Index<Element>) -> Element {
        _read {
            let pointer = unsafe _readBase() + Index<Element>.Offset(fromZero: slot)
            yield unsafe pointer.pointee
        }
        _modify {
            let pointer = unsafe _mutableBase() + Index<Element>.Offset(fromZero: slot)
            yield &(unsafe pointer.pointee)
        }
    }

    /// Initializes the uninitialized slot at `slot` (uninit → init; extends the linear-prefix ledger).
    @inlinable
    public mutating func initialize(at slot: Index<Element>, to element: consuming Element) {
        let pointer = unsafe _mutableBase() + Index<Element>.Offset(fromZero: slot)
        unsafe pointer.initialize(to: element)
        _initialization = .linear(count: count + .one)
    }

    /// Moves the initialized element out of `slot` (init → uninit; shrinks the linear-prefix ledger).
    @inlinable
    public mutating func move(at slot: Index<Element>) -> Element {
        let pointer = unsafe _mutableBase() + Index<Element>.Offset(fromZero: slot)
        let element = unsafe pointer.move()
        _initialization = .linear(count: count.subtract.saturating(.one))
        return element
    }
}

// MARK: - Conformance (the 4-op convenience seam)

extension Store.Inline: Store.`Protocol` {}
