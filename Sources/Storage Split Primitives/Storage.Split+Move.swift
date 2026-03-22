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
internal import Property_Primitives

// MARK: - Move Accessor

extension Storage.Split where Element: ~Copyable {
    /// Accessor for move operations on split storage.
    ///
    /// ```swift
    /// let value = storage.move(element, at: slot)
    /// ```
    @inlinable
    public var move: Property<Storage.Move, Storage.Split<Lane>> {
        Property(self)
    }
}

extension Property {
    /// Moves the value at the given slot in the given field, leaving it uninitialized.
    ///
    /// - Parameters:
    ///   - field: The field handle identifying which array to access.
    ///   - slot: The physical slot to move from.
    /// - Returns: The moved value.
    /// - Precondition: The slot must contain an initialized value.
    @inlinable
    public func callAsFunction<Element: ~Copyable, Lane: BitwiseCopyable, Value: ~Copyable>(
        _ field: Storage<Element>.Field<Value>,
        at slot: Index<Element>
    ) -> Value where Tag == Storage<Element>.Move, Base == Storage<Element>.Split<Lane> {
        unsafe base.pointer(field, at: slot).move()
    }
}
