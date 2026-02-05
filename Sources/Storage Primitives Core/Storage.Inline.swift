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

/// Internal raw storage with automatic layout computation.
///
/// Uses `@_rawLayout(likeArrayOf: Element, count: capacity)` to compute optimal
/// layout at compile time: `size = stride(Element) × capacity`, `alignment = alignment(Element)`.
///
/// This type has no stored properties — the layout is determined entirely by the attribute.
@_rawLayout(likeArrayOf: Element, count: capacity)
@usableFromInline
package struct _RawInlineStorage<Element: ~Copyable, let capacity: Int>: ~Copyable {
    @usableFromInline
    init() {}
}

// @_rawLayout types require @unchecked Sendable
extension _RawInlineStorage: @unchecked Sendable where Element: Sendable {}

extension Storage {
    /// Fixed-capacity inline storage with automatic optimal layout.
    ///
    /// Provides stack-allocated storage with compile-time capacity. Elements are
    /// stored inline without heap allocation, making this suitable for small,
    /// fixed-size collections.
    ///
    /// ## Layout
    ///
    /// Storage uses `@_rawLayout` for automatic optimal layout computation:
    /// - Size: `MemoryLayout<Element>.stride × capacity`
    /// - Alignment: `MemoryLayout<Element>.alignment`
    ///
    /// This eliminates the 64-byte slot overhead of previous implementations.
    ///
    /// ## Initialization Tracking
    ///
    /// Tracks initialization state via the `_initialization` field. Use
    /// `deinitialize()` to clean up all tracked initialized slots.
    ///
    /// ## Span Compatibility
    ///
    /// With optimal layout, `Storage.Inline` now stores elements contiguously
    /// at their natural stride, enabling potential Span access for Copyable elements.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// var storage = Storage.Inline<Int, 8>()
    /// storage.initialize(to: 42, at: .zero)
    /// let value = storage.move(at: .zero)
    /// ```
    public struct Inline<Element: ~Copyable, let capacity: Int>: ~Copyable {
        @usableFromInline
        package var _storage: _RawInlineStorage<Element, capacity>

        @usableFromInline
        package var _initialization: Initialization

        /// Creates uninitialized inline storage.
        ///
        /// Layout is computed automatically — no validation required.
        @inlinable
        public init() {
            _storage = _RawInlineStorage()
            _initialization = .empty
        }
    }
}

// MARK: - Conditional Conformances

// Note: Storage.Inline cannot be conditionally Copyable because _RawInlineStorage
// (an @_rawLayout type) is always ~Copyable. This is acceptable since Storage.Inline
// manages initialization state and ~Copyable is the correct semantic.

/// `Storage.Inline` is `Sendable` when its elements are `Sendable`.
/// Requires @unchecked because _RawInlineStorage uses @unchecked Sendable.
extension Storage.Inline: @unchecked Sendable where Element: Sendable {}
