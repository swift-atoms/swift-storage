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

public import Index_Primitives
public import Pointer_Primitives
public import Range_Primitives
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
/// - `Storage.Inline<N>`: Fixed-capacity inline storage
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
        get { Index<Element>.Count(__unchecked: (), header) }
        @inline(__always)
        set { header = Int(newValue.count.rawValue) }
    }

    deinit {
        let count = self.count
        guard count > .zero else { return }
        _ = unsafe withUnsafeMutablePointerToElements { elements in
            (.zero..<count).forEach { index in
                unsafe (elements + index).deinitialize(count: 1)
            }
        }
    }
    
    /// Namespace for storage header types.
    ///
    /// Headers track the metadata required for different storage layouts:
    ///
    /// - ``Header/Count``: Element count for contiguous storage (Array, Stack)
    /// - ``Header/Ring``: Head/tail/count for circular buffers (Queue, Deque)
    /// - ``Header/Arena``: Free list management for arena storage (List)
    public enum Header {}
    
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

        /// The slot stride (64 bytes per slot).
        @usableFromInline
        static var slotStride: Index<UInt8>.Count { Index<UInt8>.Count.init(__unchecked: (), 64) }

        /// Maximum element stride supported (64 bytes per slot).
        @inlinable
        public static var maxStride: Int { 64 }

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
    }
    
    /// Circular buffer storage operations.
    ///
    /// Operations for ring buffer storage where elements wrap around the capacity
    /// boundary. Used by Queue and Deque.
    ///
    /// ## Ring Buffer Semantics
    ///
    /// Ring buffers maintain a circular view over contiguous storage. Elements are
    /// logically ordered from head to tail, but physically wrap at capacity:
    ///
    /// ```
    /// Physical:  [ 2 | 3 | 4 | 0 | 1 ]
    ///                        ^head
    /// Logical:   [ 0 | 1 | 2 | 3 | 4 ]
    /// ```
    ///
    /// All operations maintain the invariant that results are in `0..<capacity`.
    public enum Ring {}
}

// MARK: - Creation

extension Storage where Element: ~Copyable {
    /// Creates storage with the specified minimum capacity.
    ///
    /// - Parameter minimumCapacity: The minimum number of elements the storage can hold.
    /// - Returns: A new storage instance with at least the requested capacity.
    @inlinable
    public static func create(minimumCapacity: Index<Element>.Count) -> Storage<Element> {
        let buffer = Storage<Element>.create(minimumCapacity: Int(minimumCapacity.count.rawValue)) { _ in 0 }
        return unsafe unsafeDowncast(buffer, to: Storage<Element>.self)
    }

    /// Creates storage with a specified capacity, initializing each element using a closure.
    ///
    /// - Parameters:
    ///   - capacity: The number of elements to allocate and initialize.
    ///   - initializer: A closure that produces the element for each index.
    /// - Returns: A new storage instance with all elements initialized.
    @inlinable
    public static func create(
        capacity: Index<Element>.Count,
        initializingWith initializer: (Index<Element>) -> Element
    ) -> Storage<Element> {
        let storage = Storage<Element>.create(minimumCapacity: Int(capacity.count.rawValue)) { _ in 0 }
        let typed = unsafe unsafeDowncast(storage, to: Storage<Element>.self)

        _ = unsafe typed.withUnsafeMutablePointerToElements { elements in
            (.zero..<capacity).forEach { index in
                unsafe (elements + index).initialize(to: initializer(index))
            }
        }
        typed.header = Int(capacity.count.rawValue)

        return typed
    }
}

// MARK: - Element Access

extension Storage where Element: ~Copyable {
    /// Returns a mutable pointer to the element at the given index.
    ///
    /// - Parameter index: The index of the element.
    /// - Returns: A mutable pointer to the element.
    /// - Warning: The caller must ensure the index is valid.
    @inlinable
    @unsafe
    public func pointer(at index: Index<Element>) -> Pointer<Element>.Mutable {
        unsafe withUnsafeMutablePointerToElements {
            unsafe Pointer<Element>.Mutable($0 + index)
        }
    }

    /// Initializes storage at the given index with the provided value.
    ///
    /// - Parameters:
    ///   - element: The value to store.
    ///   - index: The index to initialize.
    /// - Precondition: The element at `index` must be uninitialized.
    @inlinable
    public func initialize(to element: consuming Element, at index: Index<Element>) {
        let ptr = unsafe pointer(at: index)
        unsafe ptr.initialize(to: element)
    }

    /// Moves the element at the given index, deinitializing that slot.
    ///
    /// - Parameter index: The index to move from.
    /// - Returns: The moved element.
    /// - Precondition: The element at `index` must be initialized.
    @inlinable
    public func move(at index: Index<Element>) -> Element {
        unsafe pointer(at: index).move()
    }

    /// Returns an immutable pointer to the element at the given index.
    ///
    /// - Parameter index: The index of the element.
    /// - Returns: An immutable pointer to the element.
    /// - Warning: The caller must ensure the index is valid.
    @inlinable
    @unsafe
    public func read(at index: Index<Element>) -> Pointer<Element> {
        unsafe withUnsafeMutablePointerToElements {
            unsafe Pointer<Element>(UnsafePointer($0 + index))
        }
    }
}

// MARK: - Bulk Operations

extension Storage where Element: ~Copyable {
    /// Deinitializes all initialized elements (uses storage's tracked count).
    ///
    /// This is a convenience overload that uses the receiver's `count` property.
    ///
    /// - Precondition: Elements at indices 0..<count must be initialized.
    @inlinable
    public func deinitialize() {
        deinitialize(count: count)
    }

    /// Deinitializes elements from index 0 up to (but not including) count.
    ///
    /// - Parameter count: The number of elements to deinitialize.
    /// - Precondition: Elements at indices 0..<count must be initialized.
    @inlinable
    public func deinitialize(count: Index<Element>.Count) {
        guard count > .zero else { return }
        _ = unsafe withUnsafeMutablePointerToElements { elements in
            (.zero..<count).forEach { index in
                unsafe (elements + index).deinitialize(count: 1)
            }
        }
        header = 0
    }

    /// Moves elements to a new storage instance.
    ///
    /// - Parameters:
    ///   - newStorage: The destination storage.
    ///   - count: The number of elements to move.
    /// - Precondition: Elements at indices 0..<count must be initialized in this storage.
    /// - Precondition: Elements at indices 0..<count must be uninitialized in newStorage.
    @inlinable
    public func move(to newStorage: Storage<Element>, count: Index<Element>.Count) {
        guard count > .zero else { return }
        _ = unsafe withUnsafeMutablePointerToElements { src in
            unsafe newStorage.withUnsafeMutablePointerToElements { dst in
                (.zero..<count).forEach { index in
                    unsafe (dst + index).initialize(to: (src + index).move())
                }
            }
        }
    }

    /// Moves all initialized elements to a new storage instance.
    ///
    /// This is a convenience method that uses the receiver's `count` property.
    ///
    /// - Parameter newStorage: The destination storage.
    /// - Precondition: Elements at indices 0..<count must be initialized in this storage.
    /// - Precondition: Elements at indices 0..<count must be uninitialized in newStorage.
    @inlinable
    public func move(to newStorage: Storage<Element>) {
        move(to: newStorage, count: count)
    }

    /// Deinitializes elements in the specified range.
    ///
    /// - Parameter range: A lazy range of indices to deinitialize.
    /// - Precondition: Elements in the range must be initialized.
    @inlinable
    public func deinitialize(in range: Range.Lazy<Index<Element>>) {
        _ = unsafe withUnsafeMutablePointerToElements { elements in
            range.forEach { index in
                unsafe (elements + index).deinitialize(count: 1)
            }
        }
    }
}

// MARK: - Copyable Extensions

extension Storage where Element: Copyable {
    /// Creates a copy of this storage with all elements.
    ///
    /// - Returns: A new storage instance with copied elements.
    @inlinable
    public func copy() -> Storage<Element> {
        let count = self.count
        guard count > .zero else {
            return Storage<Element>.create(minimumCapacity: .zero)
        }

        let new = Storage<Element>.create(minimumCapacity: count)
        new.header = Int(count.count.rawValue)

        _ = unsafe withUnsafeMutablePointerToElements { src in
            unsafe new.withUnsafeMutablePointerToElements { dst in
                (.zero..<count).forEach { index in
                    unsafe (dst + index).initialize(to: src[index])
                }
            }
        }

        return new
    }

    /// Copies all initialized elements to a new storage instance.
    ///
    /// - Parameter newStorage: The destination storage.
    /// - Precondition: Elements at indices 0..<count must be initialized in this storage.
    /// - Precondition: Elements at indices 0..<count must be uninitialized in newStorage.
    @inlinable
    public func copy(to newStorage: Storage<Element>) {
        let count = self.count
        guard count > .zero else { return }
        _ = unsafe withUnsafeMutablePointerToElements { src in
            unsafe newStorage.withUnsafeMutablePointerToElements { dst in
                (.zero..<count).forEach { index in
                    unsafe (dst + index).initialize(to: src[index])
                }
            }
        }
    }
}

// MARK: - Semantic Alias

extension Storage {
    /// Semantic alias - Storage IS contiguous heap storage.
    public typealias Contiguous = Storage
}
