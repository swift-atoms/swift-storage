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
        ///
        /// - Precondition: Element stride must not exceed 64 bytes (inline slot size).
        /// - Precondition: Element alignment must not exceed `Int` alignment.
        @inlinable
        public init() {
            precondition(
                MemoryLayout<Element>.stride <= 64,
                "Element stride exceeds inline storage slot size (64 bytes)"
            )
            precondition(
                MemoryLayout<Element>.alignment <= MemoryLayout<Int>.alignment,
                "Element alignment exceeds inline storage alignment"
            )
            _storage = .init(repeating: (0, 0, 0, 0, 0, 0, 0, 0))
        }

        /// Returns an immutable pointer to the element at the given index.
        ///
        /// - Parameter index: The index of the element.
        /// - Returns: A pointer to the element.
        /// - Precondition: The element at `index` must be initialized.
        /// - Note: This method is mutating to ensure pointer stability.
        @inlinable
        public mutating func pointer(at index: Index<Element>) -> Pointer<Element> {
            let stride = MemoryLayout<Element>.stride
            return unsafe withUnsafeMutablePointer(to: &_storage) { base in
                let rawBase = unsafe UnsafeRawPointer(base)
                let ptr = unsafe (rawBase + index.position.rawValue * stride)
                    .assumingMemoryBound(to: Element.self)
                return unsafe Pointer<Element>(ptr)
            }
        }

        /// Returns a mutable pointer to the element at the given index.
        ///
        /// - Parameter index: The index of the element.
        /// - Returns: A mutable pointer to the element.
        /// - Precondition: The element at `index` must be initialized.
        @inlinable
        public mutating func mutablePointer(at index: Index<Element>) -> Pointer<Element>.Mutable {
            let stride = MemoryLayout<Element>.stride
            return unsafe withUnsafeMutablePointer(to: &_storage) { base in
                let rawBase = unsafe UnsafeMutableRawPointer(base)
                let ptr = unsafe (rawBase + index.position.rawValue * stride)
                    .assumingMemoryBound(to: Element.self)
                return unsafe Pointer<Element>.Mutable(ptr)
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
            let stride = MemoryLayout<Element>.stride
            _ = unsafe withUnsafeMutablePointer(to: &_storage) { base in
                let rawBase = unsafe UnsafeMutableRawPointer(base)
                for i in 0..<count.rawValue {
                    unsafe (rawBase + i * stride)
                        .assumingMemoryBound(to: Element.self)
                        .deinitialize(count: 1)
                }
            }
        }

        /// Deinitializes elements in the specified range.
        ///
        /// - Parameter range: A lazy range of indices to deinitialize.
        /// - Precondition: Elements in the range must be initialized.
        @inlinable
        public mutating func deinitialize(in range: Range.Lazy<Index<Element>>) {
            let stride = MemoryLayout<Element>.stride
            _ = unsafe withUnsafeMutablePointer(to: &_storage) { base in
                let rawBase = unsafe UnsafeMutableRawPointer(base)
                range.forEach { index in
                    unsafe (rawBase + index.position.rawValue * stride)
                        .assumingMemoryBound(to: Element.self)
                        .deinitialize(count: 1)
                }
            }
        }

        /// Moves elements from this inline storage to heap storage.
        ///
        /// - Parameters:
        ///   - heapStorage: The destination heap storage.
        ///   - count: The number of elements to move.
        /// - Precondition: Elements at indices 0..<count must be initialized in this storage.
        /// - Precondition: Elements at indices 0..<count must be uninitialized in heapStorage.
        @inlinable
        public mutating func move(to heapStorage: Storage<Element>, count: Index<Element>.Count) {
            guard count > .zero else { return }
            let stride = MemoryLayout<Element>.stride
            _ = unsafe withUnsafeMutablePointer(to: &_storage) { base in
                unsafe heapStorage.withUnsafeMutablePointerToElements { dst in
                    let rawBase = unsafe UnsafeMutableRawPointer(base)
                    (0..<count).forEach { index in
                        let src = unsafe (rawBase + index.position.rawValue * stride)
                            .assumingMemoryBound(to: Element.self)
                        unsafe (dst + index.position.rawValue).initialize(to: src.move())
                    }
                }
            }
        }
    }
}

// MARK: - Copyable Extensions for Inline Storage

extension Storage.Inline where Element: Copyable {
    /// Copies elements from this inline storage to heap storage.
    ///
    /// - Parameters:
    ///   - heapStorage: The destination heap storage.
    ///   - count: The number of elements to copy.
    /// - Precondition: Elements at indices 0..<count must be initialized in this storage.
    /// - Precondition: Elements at indices 0..<count must be uninitialized in heapStorage.
    @inlinable
    public func copy(to heapStorage: Storage<Element>, count: Index<Element>.Count) {
        guard count > .zero else { return }
        let stride = MemoryLayout<Element>.stride
        _ = unsafe withUnsafePointer(to: _storage) { base in
            unsafe heapStorage.withUnsafeMutablePointerToElements { dst in
                let rawBase = unsafe UnsafeRawPointer(base)
                (0..<count).forEach { index in
                    let src = unsafe (rawBase + index.position.rawValue * stride)
                        .assumingMemoryBound(to: Element.self)
                    unsafe (dst + index.position.rawValue).initialize(to: src.pointee)
                }
            }
        }
    }
}
