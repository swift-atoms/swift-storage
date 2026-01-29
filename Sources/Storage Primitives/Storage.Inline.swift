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

extension Storage.Inline where Element: ~Copyable {

    /// Returns an immutable pointer to the element at the given index.
    ///
    /// - Parameter index: The index of the element.
    /// - Returns: A pointer to the element.
    /// - Precondition: The element at `index` must be initialized.
    /// - Note: This method is mutating to ensure pointer stability.
    @inlinable
    public mutating func pointer(at index: Index<Element>) -> Pointer<Element> {
        unsafe withUnsafeMutablePointer(to: &_storage) { base in
            let ptr = unsafe UnsafePointer(UnsafeMutableRawPointer(base)
                .assumingMemoryBound(to: Element.self)
                .advanced(by: Int(bitPattern: index)))
            return unsafe Pointer<Element>(ptr)
        }
    }

    // MARK: - Span Access (Closure-Based)
    //
    // Inline storage has unstable address (struct can move). Per span-access-abstraction
    // research, inline storage MUST use closure-based span access, not property-based.
    // The closure scope ensures the pointer is valid for the duration of use.
    //
    // Dense element packing enables direct Span creation from the storage pointer.

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
        let result: R? = unsafe Swift.withUnsafePointer(to: _storage) { base in
            let ptr = unsafe UnsafeRawPointer(base).assumingMemoryBound(to: Element.self)
            let span = unsafe Span(_unsafeStart: ptr, count: Int(bitPattern: count))
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

    /// Provides mutable span access to the first `count` elements.
    ///
    /// The span is valid only for the duration of the closure.
    ///
    /// - Parameters:
    ///   - count: The number of initialized elements.
    ///   - body: A closure that receives the mutable span.
    /// - Returns: The value returned by the closure.
    /// - Throws: Rethrows any error thrown by the closure.
    /// - Precondition: Elements at indices 0..<count must be initialized.
    @inlinable
    public mutating func withMutableSpan<R, E: Swift.Error>(
        count: Index<Element>.Count,
        _ body: (inout MutableSpan<Element>) throws(E) -> R
    ) throws(E) -> R {
        var thrown: E? = nil
        let result: R? = unsafe Swift.withUnsafeMutablePointer(to: &_storage) { base in
            let ptr = unsafe UnsafeMutableRawPointer(base).assumingMemoryBound(to: Element.self)
            var span = unsafe MutableSpan(_unsafeStart: ptr, count: Int(bitPattern: count))
            do {
                return try body(&span)
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

    /// Returns a mutable pointer to the element at the given index.
    ///
    /// - Parameter index: The index of the element.
    /// - Returns: A mutable pointer to the element.
    /// - Precondition: The element at `index` must be initialized.
    @inlinable
    public mutating func pointer(at index: Index<Element>) -> Pointer<Element>.Mutable {
        unsafe withUnsafeMutablePointer(to: &_storage) { base in
            let ptr = unsafe UnsafeMutableRawPointer(base)
                .assumingMemoryBound(to: Element.self)
                .advanced(by: Int(bitPattern: index))
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
        pointer(at: index).initialize(to: value)
    }

    /// Moves the element at the given index, deinitializing that slot.
    ///
    /// - Parameter index: The index to move from.
    /// - Returns: The moved element.
    /// - Precondition: The element at `index` must be initialized.
    @inlinable
    public mutating func move(at index: Index<Element>) -> Element {
        pointer(at: index).move()
    }

    /// Deinitializes elements from index 0 up to (but not including) count.
    ///
    /// - Parameter count: The number of elements to deinitialize.
    /// - Precondition: Elements at indices 0..<count must be initialized.
    /// - Note: Non-mutating to allow use from deinit contexts.
    @inlinable
    public func deinitialize(count: Index<Element>.Count) {
        _ = unsafe withUnsafePointer(to: _storage) { base in
            let ptr = unsafe UnsafeMutableRawPointer(mutating: base).assumingMemoryBound(to: Element.self)
            (.zero..<count).forEach { index in
                unsafe ptr.advanced(by: Int(bitPattern: index)).deinitialize(count: 1)
            }
        }
    }

    /// Deinitializes elements in the specified range.
    ///
    /// - Parameter range: A lazy range of indices to deinitialize.
    /// - Precondition: Elements in the range must be initialized.
    /// - Note: Non-mutating to allow use from deinit contexts.
    @inlinable
    public func deinitialize(in range: Range.Lazy<Index<Element>>) {
        _ = unsafe withUnsafePointer(to: _storage) { base in
            let ptr = unsafe UnsafeMutableRawPointer(mutating: base).assumingMemoryBound(to: Element.self)
            range.forEach { index in
                unsafe ptr.advanced(by: Int(bitPattern: index)).deinitialize(count: 1)
            }
        }
    }

    /// Deinitializes elements in ring buffer order.
    ///
    /// For inline storage used as a ring buffer. Overloads `deinitialize(count:)`
    /// with ring-aware traversal indicated by `head` parameter.
    ///
    /// - Parameters:
    ///   - head: Physical index of first element.
    ///   - count: Number of elements to deinitialize.
    /// - Precondition: Elements from head through count positions must be initialized.
    /// - Note: Non-mutating to allow use from deinit contexts.
    @inlinable
    public func deinitialize(head: Index<Element>, count: Index<Element>.Count) {
        guard count > .zero else { return }
        let cap = Index<Element>.Count(UInt(Self.capacity))
        var index = head
        _ = unsafe withUnsafePointer(to: _storage) { base in
            let ptr = unsafe UnsafeMutableRawPointer(mutating: base).assumingMemoryBound(to: Element.self)
            (.zero..<count).forEach { _ in
                unsafe ptr.advanced(by: Int(bitPattern: index)).deinitialize(count: 1)
                index = Storage<Element>.Ring.successor(of: index, wrapping: cap)
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
        _ = unsafe withUnsafeMutablePointer(to: &_storage) { base in
            let srcPtr = unsafe UnsafeMutableRawPointer(base).assumingMemoryBound(to: Element.self)
            unsafe heapStorage.withUnsafeMutablePointerToElements { destination in
                (.zero..<count).forEach { index in
                    let i = Int(bitPattern: index)
                    unsafe (destination + index).initialize(to: srcPtr.advanced(by: i).move())
                }
            }
        }
    }
}

