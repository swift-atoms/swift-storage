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
public import Memory_Heap_Primitives
public import Storage_Contiguous_Primitives
internal import Property_Primitives
public import Storage_Accessor_Primitives
public import Storage_Initialization_Primitives
public import Memory_Heap_Primitives
public import Storage_Primitive

// MARK: - Copy Accessor

extension Storage.Contiguous where Element: Copyable, Substrate == Memory.Heap<Element> {
    /// Accessor for copy operations.
    ///
    /// Provides bulk copy of initialized elements between storages.
    ///
    /// ```swift
    /// let new = heap.copy()                        // Clone to new storage
    /// heap.copy(to: destination)                   // Copy to existing storage
    /// heap.copy(range: range, to: destination)     // Copy range to slot 0
    /// heap.copy(range: range, to: dest, at: offset) // Copy range at offset
    /// ```
    @inlinable
    public var copy: Property<Storage.Copy, Self>.Inout {
        mutating _read {
            yield Property<Storage.Copy, Self>.Inout(&self)
        }
        mutating _modify {
            var accessor = Property<Storage.Copy, Self>.Inout(&self)
            yield &accessor
        }
    }
}

// MARK: - Copy Methods

extension Property.Inout where Base: ~Copyable {
    /// Copies elements in `range` from source to `destination` starting at `offset`.
    ///
    /// This is the primitive copy operation. All other copy methods delegate to this.
    ///
    /// - Parameters:
    ///   - range: The contiguous range of slots to copy from.
    ///   - destination: The destination storage.
    ///   - offset: The destination slot to start writing at.
    /// - Precondition: All slots in the range must contain initialized elements.
    /// - Precondition: Destination slots offset..<(offset + range.count) must be uninitialized.
    @inlinable
    public func callAsFunction<Element: Copyable>(
        range: Swift.Range<Index<Element>>,
        to destination: borrowing Storage<Element>.Contiguous<Memory.Heap<Element>>,
        at offset: Index<Element>
    ) where Tag == Storage<Element>.Copy, Base == Storage<Element>.Contiguous<Memory.Heap<Element>> {
        guard !range.isEmpty else { return }
        unsafe destination.pointer(at: offset)
            .initialize(from: base.value.pointer(at: range.lowerBound), count: range.count)
    }

    /// Copies elements in `range` from source to slot 0 in `destination`.
    ///
    /// - Parameters:
    ///   - range: The contiguous range of slots to copy from.
    ///   - destination: The destination storage.
    /// - Precondition: All slots in the range must contain initialized elements.
    /// - Precondition: Destination slots 0..<range.count must be uninitialized.
    @inlinable
    public func callAsFunction<Element: Copyable>(
        range: Swift.Range<Index<Element>>,
        to destination: borrowing Storage<Element>.Contiguous<Memory.Heap<Element>>
    ) where Tag == Storage<Element>.Copy, Base == Storage<Element>.Contiguous<Memory.Heap<Element>> {
        self(range: range, to: destination, at: .zero)
    }

    /// Creates a new storage with all initialized elements copied linearly.
    ///
    /// Disjoint ranges are packed into contiguous positions in the new storage.
    ///
    /// - Returns: A new storage instance with copied elements.
    @inlinable
    public func callAsFunction<Element: Copyable>() -> Storage<Element>.Contiguous<Memory.Heap<Element>>
    where Tag == Storage<Element>.Copy, Base == Storage<Element>.Contiguous<Memory.Heap<Element>> {
        let count = base.value.initialization.count
        let new = Storage<Element>.Contiguous<Memory.Heap<Element>>.create(minimumCapacity: count)
        new.initialization = .linear(count: count)
        self(to: new)
        return new
    }

    /// Copies all initialized elements to `destination` linearly from slot 0.
    ///
    /// Disjoint ranges are packed into contiguous positions in the destination.
    ///
    /// - Parameter destination: The destination storage.
    /// - Precondition: Destination must have sufficient capacity.
    @inlinable
    public func callAsFunction<Element: Copyable>(
        to destination: borrowing Storage<Element>.Contiguous<Memory.Heap<Element>>
    ) where Tag == Storage<Element>.Copy, Base == Storage<Element>.Contiguous<Memory.Heap<Element>> {
        base.value.initialization.linearize { range, offset in
            self(range: range, to: destination, at: offset)
        }
    }
}
