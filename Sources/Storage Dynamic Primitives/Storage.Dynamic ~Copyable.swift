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
public import Index_Primitives
import Range_Primitives

// MARK: - Index-Based API (Backward Compatibility)
//
// These methods accept Index<Element> and convert to Storage.Slot internally.
// This provides backward compatibility while the codebase transitions to
// slot-based APIs.

extension Storage.Heap where Element: ~Copyable {
    /// Returns a mutable pointer to the element at the given index.
    ///
    /// - Parameter index: The logical index of the element.
    /// - Returns: A mutable pointer to the element.
    /// - Warning: The caller must ensure the index is valid.
    /// - Note: This method converts the index to a physical slot internally.
    @inlinable
    @unsafe
    public func pointer(at index: Index<Element>) -> UnsafeMutablePointer<Element> {
        let slot = Storage.Slot(Ordinal(index.rawValue.rawValue))
        return unsafe pointer(at: slot)
    }

    /// Initializes storage at the given index with the provided value.
    ///
    /// - Parameters:
    ///   - element: The value to store.
    ///   - index: The logical index to initialize.
    /// - Precondition: The element at `index` must be uninitialized.
    /// - Note: This method converts the index to a physical slot internally.
    @inlinable
    public func initialize(to element: consuming Element, at index: Index<Element>) {
        let slot = Storage.Slot(Ordinal(index.rawValue.rawValue))
        initialize(to: element, at: slot)
    }

    /// Moves the element at the given index, deinitializing that slot.
    ///
    /// - Parameter index: The logical index to move from.
    /// - Returns: The moved element.
    /// - Precondition: The element at `index` must be initialized.
    /// - Note: This method converts the index to a physical slot internally.
    @inlinable
    public func move(at index: Index<Element>) -> Element {
        let slot = Storage.Slot(Ordinal(index.rawValue.rawValue))
        return move(at: slot)
    }
}

// MARK: - Legacy Count Property
//
// For backward compatibility, provides a count property that reads from
// initialization state.

extension Storage.Heap where Element: ~Copyable {
    /// The number of initialized elements in storage (read-only).
    ///
    /// This property reads from the initialization state.
    /// To set initialization, use `header.initialization = .linear(count:)` or `.empty`.
    ///
    /// - Note: For new code, prefer using `header.initialization.initializedCount`.
    @inlinable
    public var count: Tagged<Element, Cardinal> {
        let slotCount = initialization.initializedCount
        return Tagged<Element, Cardinal>(__unchecked: (), Cardinal(slotCount.rawValue.rawValue))
    }
}

// MARK: - Span Access (Index-Based)

extension Storage.Heap where Element: ~Copyable {
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
        let span = Storage.Span(
            start: .zero,
            count: Storage.Slot.Count(count.rawValue.rawValue)
        )
        return try withSpan(span, body)
    }

    /// Provides read-only span access using the storage's tracked count.
    @inlinable
    public func withSpan<R, E: Swift.Error>(
        _ body: (Span<Element>) throws(E) -> R
    ) throws(E) -> R {
        try withSpan(count: count, body)
    }
}

// MARK: - Bulk Operations (Index-Based)

extension Storage.Heap where Element: ~Copyable {
    /// Deinitializes elements from index 0 up to (but not including) count.
    ///
    /// - Parameter count: The number of elements to deinitialize.
    /// - Precondition: Elements at indices 0..<count must be initialized.
    @inlinable
    public func deinitialize(count: Index<Element>.Count) {
        guard count > .zero else { return }
        _ = unsafe withUnsafeMutablePointerToElements { elements in
            (.zero..<count).forEach { index in
                let offset = Int(bitPattern: index.rawValue.rawValue)
                unsafe (elements + offset).deinitialize(count: 1)
            }
        }
        header.initialization = .empty
    }

    /// Deinitializes all initialized elements (uses storage's tracked count).
    ///
    /// This is a convenience overload that uses the receiver's `count` property.
    ///
    /// - Precondition: Elements at indices 0..<count must be initialized.
    @inlinable
    public func deinitialize() {
        deinitialize(count: count)
    }

    /// Moves elements to a new storage instance.
    ///
    /// - Parameters:
    ///   - newStorage: The destination storage.
    ///   - count: The number of elements to move.
    /// - Precondition: Elements at indices 0..<count must be initialized in this storage.
    /// - Precondition: Elements at indices 0..<count must be uninitialized in newStorage.
    @inlinable
    public func move(to newStorage: Storage.Heap<Element>, count: Index<Element>.Count) {
        guard count > .zero else { return }
        _ = unsafe withUnsafeMutablePointerToElements { src in
            unsafe newStorage.withUnsafeMutablePointerToElements { dst in
                (.zero..<count).forEach { index in
                    let offset = Int(bitPattern: index.rawValue.rawValue)
                    unsafe (dst + offset).initialize(to: (src + offset).move())
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
    public func move(to newStorage: Storage.Heap<Element>) {
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
                let offset = Int(bitPattern: index.rawValue.rawValue)
                unsafe (elements + offset).deinitialize(count: 1)
            }
        }
    }
}
