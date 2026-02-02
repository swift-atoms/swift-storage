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
    /// - ``Header/Arena``: Free list management for arena storage (List)
    ///
    /// For ring buffer headers, see `Buffer.Ring.Header` in buffer-primitives.
    public enum Header {}
    
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

    // MARK: - Span Access (Closure-Based)
    //
    // Even though heap storage has stable address, Span is ~Escapable and the
    // compiler enforces lifetime scoping. Use closure-based access for safety.

    /// Provides read-only span access to the first `count` elements.
    ///
    /// The span is valid only for the duration of the closure.
    ///
    /// - Parameters:
    ///   - count: The number of initialized elements.
    ///   - body: A closure that receives the span.
    /// - Returns: The value returned by the closure.
    /// - Throws: Rethrows any error thrown by the closure.
    /// - Precondition: Elements at indices 0..<count must be initialized.
    @inlinable
    public func withSpan<R, E: Swift.Error>(
        count: Index<Element>.Count,
        _ body: (Span<Element>) throws(E) -> R
    ) throws(E) -> R {
        var thrown: E? = nil
        let result: R? = unsafe withUnsafeMutablePointerToElements { base in
            let span = unsafe Span(_unsafeStart: UnsafePointer(base), count: Int(bitPattern: count))
            do {
                return try body(span)
            } catch let e as E {
                thrown = e
                return nil
            } catch {
                preconditionFailure("unexpected error type")
            }
        }
        if let thrown { throw thrown }
        return result!
    }

    /// Provides read-only span access using the storage's tracked count.
    @inlinable
    public func withSpan<R, E: Swift.Error>(
        _ body: (Span<Element>) throws(E) -> R
    ) throws(E) -> R {
        try withSpan(count: count, body)
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

    /// Shifts elements left to fill a gap at the removed index.
    ///
    /// Moves elements from `[removedAt+1, count)` to `[removedAt, count-1)`,
    /// then decrements the stored count.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Before: [A, B, C, D] count=4, remove at index 1
    /// storage.shiftLeft(removedAt: Index(1))
    /// // After:  [A, C, D, _] count=3
    /// ```
    ///
    /// - Parameter removedAt: The index where an element was removed.
    /// - Precondition: `removedAt` must be less than `count`.
    /// - Precondition: The element at `removedAt` must already be deinitialized.
    @inlinable
    public func shiftLeft(removedAt index: Index<Element>) {
        let currentCount = self.count
        let newCount = currentCount.subtract.saturating(.one)

        // If removing the last element, just decrement count
        guard index < newCount else {
            self.count = newCount
            return
        }

        // Shift elements left: move [index+1, currentCount) to [index, currentCount-1)
        _ = unsafe withUnsafeMutablePointerToElements { elements in
            (index..<newCount).forEach { destIndex in
                let srcIndex = destIndex + .one
                unsafe (elements + destIndex).initialize(to: (elements + srcIndex).move())
            }
        }
        self.count = newCount
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
        let countInt = Int(bitPattern: count)

        let new = unsafe unsafeDowncast(
            Storage<Element>.create(minimumCapacity: countInt) { _ in countInt },
            to: Storage<Element>.self
        )

        guard count > .zero else { return new }

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

    /// Semantic alias for inline storage.
    public typealias Inline = Static
}
