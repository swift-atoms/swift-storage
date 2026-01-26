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
public import Affine_Primitives
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
        get { .init(__unchecked: header) }
        @inline(__always)
        set { header = newValue.rawValue }
    }

    deinit {
        let count = header
        guard count > 0 else { return }
        _ = unsafe withUnsafeMutablePointerToElements { elements in
            for i in 0..<count {
                unsafe (elements + i).deinitialize(count: 1)
            }
        }
    }
}

// MARK: - Creation

extension Storage where Element: ~Copyable {
    /// Creates storage with the specified minimum capacity.
    ///
    /// - Parameter minimumCapacity: The minimum number of elements the storage can hold.
    /// - Returns: A new storage instance with at least the requested capacity.
    @inlinable
    public static func create(minimumCapacity: Index<Element>.Count) -> Storage<Element> {
        let buffer = Storage<Element>.create(minimumCapacity: minimumCapacity.rawValue) { _ in 0 }
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
        let storage = Storage<Element>.create(minimumCapacity: capacity.rawValue) { _ in 0 }
        let typed = unsafe unsafeDowncast(storage, to: Storage<Element>.self)

        _ = unsafe typed.withUnsafeMutablePointerToElements { elements in
            (0..<capacity).forEach { index in
                unsafe (elements + index.position.rawValue).initialize(to: initializer(index))
            }
        }
        typed.header = capacity.rawValue

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
            unsafe Pointer<Element>.Mutable($0 + index.position.rawValue)
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
            unsafe Pointer<Element>(UnsafePointer($0 + index.position.rawValue))
        }
    }
}

// MARK: - Bulk Operations

extension Storage where Element: ~Copyable {
    /// Deinitializes elements from index 0 up to (but not including) count.
    ///
    /// - Parameter count: The number of elements to deinitialize.
    /// - Precondition: Elements at indices 0..<count must be initialized.
    @inlinable
    public func deinitialize(count: Index<Element>.Count) {
        guard count > .zero else { return }
        _ = unsafe withUnsafeMutablePointerToElements { elements in
            for i in 0..<count.rawValue {
                unsafe (elements + i).deinitialize(count: 1)
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
                for i in 0..<count.rawValue {
                    unsafe (dst + i).initialize(to: (src + i).move())
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
                unsafe (elements + index.position.rawValue).deinitialize(count: 1)
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
        new.header = count.rawValue

        _ = unsafe withUnsafeMutablePointerToElements { src in
            unsafe new.withUnsafeMutablePointerToElements { dst in
                for i in 0..<count.rawValue {
                    unsafe (dst + i).initialize(to: src[i])
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
                for i in 0..<count.rawValue {
                    unsafe (dst + i).initialize(to: src[i])
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
