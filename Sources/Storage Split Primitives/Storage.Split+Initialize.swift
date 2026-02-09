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
public import Property_Primitives

// MARK: - Initialize Accessor

extension Storage.Split where Element: ~Copyable, Lane: ~Copyable {
    /// Accessor for initialize operations on split storage.
    ///
    /// ```swift
    /// storage.initialize(element, to: value, at: slot)
    /// ```
    @inlinable
    public var initialize: Property<Storage.Initialize, Storage.Split<Lane>> {
        Property(self)
    }
}

extension Property {
    /// Initializes the value at the given slot in the given field.
    ///
    /// - Parameters:
    ///   - field: The field handle identifying which array to access.
    ///   - value: The value to store.
    ///   - slot: The physical slot to initialize.
    /// - Precondition: The slot must be uninitialized.
    @inlinable
    public func callAsFunction<Element: ~Copyable, Lane: ~Copyable, Value: ~Copyable>(
        _ field: Storage<Element>.Field<Value>,
        to value: consuming Value,
        at slot: Index<Element>
    ) where Tag == Storage<Element>.Initialize, Base == Storage<Element>.Split<Lane> {
        unsafe base.pointer(field, at: slot).initialize(to: value)
    }
}
