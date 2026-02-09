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

// MARK: - Convenience Factory

extension Storage.Split where Element: ~Copyable, Lane: Copyable {
    /// Creates split storage with the given capacity, bulk-initializing the lane.
    ///
    /// Lane slots are initialized to `laneInitial`. Element slots are uninitialized.
    /// This is the standard factory for the common case where the lane type is
    /// Copyable (e.g., `UInt8` metadata bytes).
    ///
    /// ```swift
    /// let storage = Storage<Index<Element>>.Split<UInt8>.create(
    ///     capacity: bucketCapacity,
    ///     laneInitial: 0x80  // Swiss table EMPTY sentinel
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - capacity: The number of slots to allocate per lane.
    ///   - laneInitial: The value to fill all lane slots with.
    /// - Returns: A new split storage with lane initialized and elements uninitialized.
    @inlinable
    public static func create(
        capacity: Index<Element>.Count,
        laneInitial: Lane
    ) -> Storage.Split<Lane> {
        let split: Storage.Split<Lane> = .create(capacity: capacity)
        unsafe split.pointer(split.laneField, at: .zero).initialize(
            repeating: laneInitial,
            count: capacity.retag(Lane.self)
        )
        return split
    }
}

// MARK: - Copyable Field Subscript

extension Storage.Split where Element: ~Copyable {
    /// Subscript access for Copyable field values.
    ///
    /// This is a field-qualified access, not a collection subscript.
    /// The field handle identifies which array; the slot identifies the position.
    ///
    /// ```swift
    /// let ctrl = storage[lane, at: bucket]      // read
    /// storage[lane, at: bucket] = h2             // write
    /// ```
    ///
    /// - Parameters:
    ///   - field: The field handle identifying which array to access.
    ///   - slot: The physical slot coordinate.
    /// - Returns: The value at the given slot in the given field.
    @inlinable
    public subscript<Value: Copyable>(
        _ field: Storage.Field<Value>, at slot: Index<Element>
    ) -> Value {
        get { unsafe pointer(field, at: slot).pointee }
        set { unsafe pointer(field, at: slot).pointee = newValue }
    }
}

// MARK: - Copyable Bulk Operations

extension Storage.Split where Element: ~Copyable {
    /// Fills all slots of the given field with the given value.
    ///
    /// Requires the field's value type to be Copyable.
    ///
    /// ```swift
    /// storage.fill(lane, with: 0x80)  // Reset all metadata to EMPTY
    /// ```
    ///
    /// - Parameters:
    ///   - field: The field handle identifying which array to fill.
    ///   - value: The value to write to every slot.
    /// - Precondition: All slots in the field must be either uninitialized
    ///   (for first fill) or initialized (for overwrite).
    @inlinable
    public func fill<Value: Copyable>(
        _ field: Storage.Field<Value>, with value: Value
    ) {
        guard header.capacity > .zero else { return }
        unsafe pointer(field, at: .zero).initialize(
            repeating: value,
            count: header.capacity.retag(Value.self)
        )
    }

    /// Calls `body` with a pointer to the contiguous array of the given field.
    ///
    /// Useful for SIMD access to lane data:
    ///
    /// ```swift
    /// storage.withPointer(lane) { ctrl in
    ///     let group = SIMD16<UInt8>(unsafePointer: ctrl + groupStart)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - field: The field handle identifying which array to access.
    ///   - body: A closure receiving a pointer to the field's contiguous array.
    /// - Returns: The value returned by `body`.
    @inlinable
    public func withPointer<Value: Copyable, R, E: Swift.Error>(
        _ field: Storage.Field<Value>,
        _ body: (UnsafePointer<Value>) throws(E) -> R
    ) throws(E) -> R {
        try unsafe body(UnsafePointer(pointer(field, at: .zero)))
    }

    /// Calls `body` with a mutable pointer to the contiguous array of the given field.
    ///
    /// - Parameters:
    ///   - field: The field handle identifying which array to access.
    ///   - body: A closure receiving a mutable pointer to the field's contiguous array.
    /// - Returns: The value returned by `body`.
    @inlinable
    public func withMutablePointer<Value: Copyable, R, E: Swift.Error>(
        _ field: Storage.Field<Value>,
        _ body: (UnsafeMutablePointer<Value>) throws(E) -> R
    ) throws(E) -> R {
        try unsafe body(pointer(field, at: .zero))
    }
}
