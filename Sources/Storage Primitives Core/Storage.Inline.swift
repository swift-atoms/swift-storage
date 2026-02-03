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

import Affine_Primitives
import Memory_Primitives_Core

extension Storage {
    /// Fixed-capacity inline storage with 64-byte slots.
    ///
    /// Provides stack-allocated storage with compile-time capacity. Elements are
    /// stored inline without heap allocation, making this suitable for small,
    /// fixed-size collections.
    ///
    /// ## Layout
    ///
    /// Storage is backed by `InlineArray` with 64-byte slots, sufficient for most
    /// element types. Elements are accessed via raw pointer operations to support
    /// move-only types.
    ///
    /// ## Initialization Tracking
    ///
    /// Tracks initialization state via the `_initialization` field. Use
    /// `deinitialize()` to clean up all tracked initialized slots.
    ///
    /// ## Span Compatibility
    ///
    /// Due to the 64-byte slot layout, `Storage.Inline` does NOT support direct
    /// Span access. Use `pointer(at:)` for element access. For dense Span access,
    /// use heap-based ``Storage/Heap`` instead.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// var storage = try Storage.Inline<Int, 8>()
    /// storage.initialize(to: 42, at: .zero)
    /// let value = storage.move(at: .zero)
    /// ```
    public struct Inline<Element: ~Copyable, let capacity: Int>: ~Copyable {
        @usableFromInline
        package var _storage: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

        @usableFromInline
        package var _initialization: Initialization

        /// Creates uninitialized inline storage.
        ///
        /// - Throws: `Error.strideExceedsSlotSize` if element stride exceeds 64 bytes.
        /// - Throws: `Error.alignmentExceedsStorageAlignment` if element alignment exceeds `Int` alignment.
        @inlinable
        public init() throws(Error) {
            guard MemoryLayout<Element>.stride <= Affine.Discrete.Ratio<Storage, Memory>.stride.factor else {
                throw .strideExceedsSlotSize(
                    stride: MemoryLayout<Element>.stride,
                    maxSlotSize: Affine.Discrete.Ratio<Storage, Memory>.stride.factor
                )
            }
            guard MemoryLayout<Element>.alignment <= MemoryLayout<Int>.alignment else {
                throw .alignmentExceedsStorageAlignment(
                    alignment: MemoryLayout<Element>.alignment,
                    maxAlignment: MemoryLayout<Int>.alignment
                )
            }
            _storage = .init(repeating: (0, 0, 0, 0, 0, 0, 0, 0))
            _initialization = .empty
        }
    }
}

// MARK: - Conditional Conformances

/// `Storage.Inline` is `Copyable` when its elements are `Copyable`.
extension Storage.Inline: Copyable where Element: Copyable {}

/// `Storage.Inline` is `Sendable` when its elements are `Sendable`.
extension Storage.Inline: Sendable where Element: Sendable {}
