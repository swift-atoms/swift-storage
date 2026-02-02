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
public import Index_Primitives
import Range_Primitives
public import Memory_Primitives
@_spi(Internal) public import Identity_Primitives

/// Namespace for storage primitives.
///
/// `Storage` provides heap and inline storage building blocks:
/// - ``Storage/Heap``: Heap-allocated storage via ManagedBuffer
/// - ``Storage/Static``: Fixed-capacity inline storage
///
/// And physical coordinate types for slot-based access:
/// - ``Storage/Slot``: Physical slot position
/// - ``Storage/Span``: Contiguous slot range
/// - ``Storage/Initialization``: Which slots are initialized
public enum Storage {
    /// Canonical heap storage using ManagedBuffer.
    ///
    /// `Storage.Heap<Element>` is the primitive heap storage building block.
    /// It provides:
    /// - Contiguous element storage
    /// - Reference semantics with manual memory management
    /// - Support for ~Copyable elements
    /// - Initialization tracking via ``Storage/Header``
    ///
    /// ## Initialization Tracking
    ///
    /// The storage tracks which slots are initialized via the `initialization`
    /// property. The deinit uses this information to correctly deinitialize
    /// only the initialized slots.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let storage = Storage.Heap<Int>.create(minimumCapacity: Storage.Slot.Count(10))
    /// storage.initialize(to: 42, at: .zero)
    /// let value = storage.move(at: .zero)
    /// ```
    public final class Heap<Element: ~Copyable>: ManagedBuffer<Header, Element> {
        deinit {
            switch header.initialization {
            case .empty:
                return
            case .one(let span):
                _deinitializeSpan(span)
            case .two(let first, let second):
                _deinitializeSpan(first)
                _deinitializeSpan(second)
            }
        }

        @usableFromInline
        internal func _deinitializeSpan(_ span: Span) {
            guard !span.isEmpty else { return }
            _ = unsafe withUnsafeMutablePointerToElements { elements in
                var slot = span.start
                while slot < span.end {
                    let offset = Int(bitPattern: slot.rawValue.rawValue)
                    unsafe (elements + offset).deinitialize(count: 1)
                    slot = slot.successor.saturating()
                }
            }
        }
    }

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
    /// Unlike the old `Storage<Element>.Static`, this type now tracks initialization
    /// state via the `_initialization` field. The caller can use `deinitializeAll()`
    /// to clean up all initialized slots.
    ///
    /// ## Span Compatibility
    ///
    /// Due to the 64-byte slot layout, `Storage.Static` does NOT support direct
    /// Span access. Use `forEach` for iteration or individual element access via
    /// `pointer(at:)`. For Span access, use heap-based ``Storage/Heap`` instead.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// var storage = try Storage.Static<Int, 8>()
    /// storage.initialize(to: 42, at: .zero)
    /// let value = storage.move(at: .zero)
    /// ```
    public struct Static<Element: ~Copyable, let capacity: Int>: ~Copyable {
        @usableFromInline
        package var _storage: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

        @usableFromInline
        package var _initialization: Initialization

        /// The slot stride (64 bytes per slot).
        @usableFromInline
        package static var slotStride: Int { 64 }

        /// Errors that can occur when creating inline storage.
        public enum Error: Swift.Error, Sendable {
            /// Element stride exceeds the inline storage slot size.
            case strideExceedsSlotSize(stride: Int, maxSlotSize: Int)
            /// Element alignment exceeds the inline storage alignment.
            case alignmentExceedsStorageAlignment(alignment: Int, maxAlignment: Int)
        }

        /// Creates uninitialized inline storage.
        ///
        /// - Throws: `Error.strideExceedsSlotSize` if element stride exceeds 64 bytes.
        /// - Throws: `Error.alignmentExceedsStorageAlignment` if element alignment exceeds `Int` alignment.
        @inlinable
        public init() throws(Error) {
            guard MemoryLayout<Element>.stride <= Self.slotStride else {
                throw .strideExceedsSlotSize(
                    stride: MemoryLayout<Element>.stride,
                    maxSlotSize: Self.slotStride
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

/// `Storage.Static` is `Copyable` when its elements are `Copyable`.
///
/// This enables value semantics for inline storage. Copying `Storage.Static`
/// creates a bitwise copy of the underlying `InlineArray`, which is valid
/// when elements are `Copyable`.
extension Storage.Static: Copyable where Element: Copyable {}

/// `Storage.Static` is `Sendable` when its elements are `Sendable`.
extension Storage.Static: Sendable where Element: Sendable {}
