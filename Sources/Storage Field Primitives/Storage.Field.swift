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

public import Affine_Primitives
public import Memory_Address_Primitives
public import Storage_Primitive

extension Storage where Element: ~Copyable {
    /// A typed field handle describing the position of a `Value` array within a split storage.
    ///
    /// Field handles are the single source of layout truth for a multi-region
    /// storage discipline (e.g. ``Storage/Split``). Consumers acquire them from
    /// a discipline instance and pass them to access methods. The byte offset
    /// and stride are exposed read-only via ``offset`` and ``stride`` so that
    /// disciplines in sibling packages can compose their own layouts.
    ///
    /// ## Properties
    ///
    /// - **Copyable and Sendable** — always, regardless of `Value`'s copyability
    /// - **Phantom-tagged** — scoped to `Storage<Element>`, preventing cross-storage misuse
    /// - **Deterministic** — layout is derived from capacity and type layout
    ///
    /// ## Usage
    ///
    /// Field handles are acquired from a ``Storage/Split`` instance and used
    /// for all access operations:
    ///
    /// ```swift
    /// let lane = storage.field.lane       // Storage<Payload>.Field<Metadata>
    /// let element = storage.field.element // Storage<Payload>.Field<Payload>
    ///
    /// storage[lane, at: slot] = 0x80
    /// unsafe storage.pointer(element, at: slot).initialize(to: value)
    /// ```
    ///
    /// Field handles are valid for the lifetime of the storage instance that
    /// produced them. Consumers should capture handles once and reuse them.
    ///
    /// - SeeAlso: ``Storage/Split``
    public struct Field<Value: ~Copyable>: Copyable, Sendable {
        /// Byte offset from the buffer base to the start of this field's array.
        @usableFromInline
        package let _offset: Memory.Address.Offset
        /// Byte stride between consecutive elements of this field.
        @usableFromInline
        package let _stride: Affine.Discrete.Ratio<Value, Memory>

        @inlinable
        package init(_offset: Memory.Address.Offset, _stride: Affine.Discrete.Ratio<Value, Memory>) {
            self._offset = _offset
            self._stride = _stride
        }

        /// Creates a field handle from a byte offset and element stride.
        ///
        /// The public construction surface for storage disciplines in sibling
        /// packages (e.g. `swift-storage-split-primitives`) that compute their
        /// own field layouts.
        public init(offset: Memory.Address.Offset, stride: Affine.Discrete.Ratio<Value, Memory>) {
            self._offset = offset
            self._stride = stride
        }

        /// Byte offset from the buffer base to the start of this field's array.
        public var offset: Memory.Address.Offset { _offset }

        /// Byte stride between consecutive elements of this field.
        public var stride: Affine.Discrete.Ratio<Value, Memory> { _stride }
    }
}
