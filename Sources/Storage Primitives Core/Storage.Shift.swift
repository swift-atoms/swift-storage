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

extension Storage {
    /// Tag type for `.shift` property extensions on storage types.
    ///
    /// Use this tag with `Property.View` to add `.shift.left(...)` functionality
    /// to storage types like `Storage.Static`.
    ///
    /// ## Available Operations
    ///
    /// | Operation | Description |
    /// |-----------|-------------|
    /// | `.shift.left(removedAt:count:)` | Shift elements left to fill a gap |
    ///
    /// ## Usage
    ///
    /// The tag is used in property accessors:
    ///
    /// ```swift
    /// var shift: Property<Shift, Self>.View.Typed<Element>.Valued<capacity> {
    ///     mutating _read {
    ///         yield unsafe Property<Shift, Self>.View.Typed<Element>.Valued<capacity>(&self)
    ///     }
    /// }
    /// ```
    public enum Shift {}
}
