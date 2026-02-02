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

/// Canonical heap storage using ManagedBuffer.
///
/// `Storage<Element>` is the primitive heap storage building block, analogous to
/// `Array.Storage` in array-primitives. It provides:
/// - Contiguous element storage
/// - Reference semantics with manual memory management
/// - Support for ~Copyable elements
///
/// ## Variants
///
/// - `Storage` / `Storage.Contiguous`: Heap storage (this type)
/// - `Storage.Static<N>`: Fixed-capacity inline storage
///
/// ## Usage
///
/// ```swift
/// let storage = Storage<Int>.create(minimumCapacity: 10)
/// storage.initialize(to: 42, at: .zero)
/// let value = storage.move(at: .zero)
/// ```
public final class Storage<Element: ~Copyable>: ManagedBuffer<Int, Element> {
    /// The number of initialized elements in storage.
    ///
    /// This property must be kept in sync with actual initialized elements.
    /// The deinit uses this value to know how many elements to deinitialize.
    @inlinable
    public var count: Index<Element>.Count {
        @inline(__always)
        get { Index<Element>.Count(UInt(bitPattern: header)) }
        @inline(__always)
        set { header = Int(bitPattern: newValue) }
    }

    deinit {
        let count = self.count
        guard count > .zero else { return }
        _ = unsafe self.withUnsafeMutablePointerToElements { elements in
            (.zero..<count).forEach { index in
                unsafe (elements + Index.Offset(__unchecked: (), index)).deinitialize(count: 1)
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
    /// ## Span Compatibility
    ///
    /// Due to the 64-byte slot layout, `Storage.Static` does NOT support direct
    /// Span access. Use `forEach` for iteration or individual element access via
    /// `pointer(at:)`. For Span access, use heap-based `Storage` instead.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// var storage = try Storage<Int>.Inline<8>()
    /// storage.initialize(to: 42, at: .zero)
    /// let value = storage.move(at: .zero)
    /// ```
    ///
    /// - Important: Caller is responsible for tracking which indices are initialized.
    public struct Static<let capacity: Int>: ~Copyable {
        @usableFromInline
        package var _storage: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

        /// The slot stride (64 bytes per slot).
        @usableFromInline
        package static var slotStride: Affine.Discrete.Ratio<Element, Memory> { .init(64) }

        /// Maximum element stride supported (64 bytes per slot).
        @inlinable
        public static var maxStride: Int { 64 }

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
            guard MemoryLayout<Element>.stride <= 64 else {
                throw .strideExceedsSlotSize(
                    stride: MemoryLayout<Element>.stride,
                    maxSlotSize: 64
                )
            }
            guard MemoryLayout<Element>.alignment <= MemoryLayout<Int>.alignment else {
                throw .alignmentExceedsStorageAlignment(
                    alignment: MemoryLayout<Element>.alignment,
                    maxAlignment: MemoryLayout<Int>.alignment
                )
            }
            _storage = .init(repeating: (0, 0, 0, 0, 0, 0, 0, 0))
        }
    }
}

