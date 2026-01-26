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

extension Storage where Element: ~Copyable {
    /// Fixed-capacity inline storage.
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
    /// ## Usage
    ///
    /// ```swift
    /// var storage = Storage<Int>.Inline<8>()
    /// storage.initialize(to: 42, at: .zero)
    /// let value = storage.move(at: .zero)
    /// ```
    ///
    /// - Important: Caller is responsible for tracking which indices are initialized.
    public struct Inline<let capacity: Int>: ~Copyable {
        @usableFromInline
        var _storage: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

        /// Creates uninitialized inline storage.
        @inlinable
        public init() {
            _storage = .init(repeating: (0, 0, 0, 0, 0, 0, 0, 0))
        }

        /// Returns an immutable pointer to the element at the given index.
        ///
        /// - Parameter index: The index of the element.
        /// - Returns: A pointer to the element.
        /// - Precondition: The element at `index` must be initialized.
        @inlinable
        public func pointer(at index: Index<Element>) -> UnsafePointer<Element> {
            unsafe withUnsafePointer(to: _storage) { base in
                unsafe UnsafeRawPointer(base)
                    .assumingMemoryBound(to: Element.self)
                    .advanced(by: index.position.rawValue)
            }
        }

        /// Returns a mutable pointer to the element at the given index.
        ///
        /// - Parameter index: The index of the element.
        /// - Returns: A mutable pointer to the element.
        /// - Precondition: The element at `index` must be initialized.
        @inlinable
        public mutating func mutablePointer(at index: Index<Element>) -> UnsafeMutablePointer<Element> {
            unsafe withUnsafeMutablePointer(to: &_storage) { base in
                unsafe UnsafeMutableRawPointer(base)
                    .assumingMemoryBound(to: Element.self)
                    .advanced(by: index.position.rawValue)
            }
        }

        /// Initializes storage at the given index with the provided value.
        ///
        /// - Parameters:
        ///   - value: The value to store.
        ///   - index: The index to initialize.
        /// - Precondition: The element at `index` must be uninitialized.
        @inlinable
        public mutating func initialize(to value: consuming Element, at index: Index<Element>) {
            unsafe mutablePointer(at: index).initialize(to: value)
        }

        /// Moves the element at the given index, deinitializing that slot.
        ///
        /// - Parameter index: The index to move from.
        /// - Returns: The moved element.
        /// - Precondition: The element at `index` must be initialized.
        @inlinable
        public mutating func move(at index: Index<Element>) -> Element {
            unsafe mutablePointer(at: index).move()
        }

        /// Deinitializes elements from index 0 up to (but not including) count.
        ///
        /// - Parameter count: The number of elements to deinitialize.
        /// - Precondition: Elements at indices 0..<count must be initialized.
        @inlinable
        public mutating func deinitialize(count: Index<Element>.Count) {
            _ = unsafe withUnsafeMutablePointer(to: &_storage) { base in
                unsafe UnsafeMutableRawPointer(base)
                    .assumingMemoryBound(to: Element.self)
                    .deinitialize(count: count.rawValue)
            }
        }
    }
}
