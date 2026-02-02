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

// MARK: - Factory

extension Storage where Element: ~Copyable {
    /// Creates storage with the specified minimum capacity.
    ///
    /// - Parameter minimumCapacity: The minimum number of elements to allocate.
    /// - Returns: A new storage instance with zero count.
    @inlinable
    public static func create(
        minimumCapacity: Index<Element>.Count
    ) -> Storage<Element> {
        unsafe unsafeDowncast(
            Storage<Element>.create(minimumCapacity: Int(bitPattern: minimumCapacity)) { _ in 0 },
            to: Storage<Element>.self
        )
    }
}

// MARK: - Fundamental Element Access

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
        ptr.initialize(to: element)
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
}
