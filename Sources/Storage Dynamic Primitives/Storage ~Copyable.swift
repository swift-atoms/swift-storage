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

public import Storage_Primitives_Core
public import Range_Primitives


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


// MARK: - Advanced Factory

extension Storage where Element: ~Copyable {
    /// Creates storage with the specified capacity and header initializer.
    ///
    /// - Parameters:
    ///   - minimumCapacity: The minimum number of elements to allocate.
    ///   - headerInitializer: A closure that returns the initial count.
    /// - Returns: A new storage instance.
    /// - Throws: Any error thrown by the header initializer.
    @inlinable
    public static func create<E: Error>(
        minimumCapacity: Index<Element>.Count,
        makingHeaderWith headerInitializer: (Storage<Element>) throws(E) -> Index<Element>.Count
    ) throws(E) -> Storage<Element> {
        var thrown: E? = nil
        let storage = unsafe unsafeDowncast(
            Storage<Element>.create(minimumCapacity: Int(bitPattern: minimumCapacity)) { buffer in
                let typed = unsafe unsafeDowncast(buffer, to: Storage<Element>.self)
                do {
                    return Int(bitPattern: try headerInitializer(typed))
                } catch let e as E {
                    thrown = e
                    return 0
                } catch {
                    preconditionFailure("unexpected error type")
                }
            },
            to: Storage<Element>.self
        )
        if let thrown { throw thrown }
        return storage
    }
}

// MARK: - Span Access

extension Storage where Element: ~Copyable {
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
