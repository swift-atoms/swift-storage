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
            let address = unsafe Memory.Mutable.Address(base)
            return address.pointer(at: index, stride: Self.slotStride, as: Element.self).immutable
        }
    }

    /// Returns a mutable pointer to the element at the given index.
    ///
    /// - Parameter index: The index of the element.
    /// - Returns: A mutable pointer to the element.
    /// - Precondition: The element at `index` must be initialized.
    @inlinable
    public mutating func pointer(at index: Index<Element>) -> Pointer<Element>.Mutable {
        unsafe withUnsafeMutablePointer(to: &_storage) { base in
            let address = unsafe Memory.Mutable.Address(base)
            return address.pointer(at: index, stride: Self.slotStride, as: Element.self)
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

    // MARK: - Iteration
    //
    // Storage.Inline uses 64-byte slots, which is incompatible with Span's
    // dense layout expectation. Provide forEach for iteration instead.

    /// Calls the given closure for each initialized element.
    ///
    /// - Parameters:
    ///   - count: The number of initialized elements.
    ///   - body: A closure that receives each element.
    /// - Precondition: Elements at indices 0..<count must be initialized.
    @inlinable
    public func forEach<E: Swift.Error>(
        count: Index<Element>.Count,
        _ body: (borrowing Element) throws(E) -> Void
    ) throws(E) {
        var thrown: E? = nil
        _ = unsafe withUnsafePointer(to: _storage) { base in
            let address = unsafe Memory.Address(base)
            (.zero..<count).forEach { index in
                guard thrown == nil else { return }
                let ptr: Pointer<Element>.Immutable = address.pointer(at: index, stride: Self.slotStride, as: Element.self)
                do {
                    try body(ptr.pointee)
                } catch let e as E {
                    thrown = e
                } catch {
                    preconditionFailure("unexpected error type")
                }
            }
        }
        if let thrown { throw thrown }
    }

    /// Provides access to the element at the given index via closure.
    ///
    /// - Parameters:
    ///   - index: The index of the element.
    ///   - body: A closure that receives a borrowed reference to the element.
    /// - Returns: The value returned by the closure.
    /// - Precondition: The element at `index` must be initialized.
    @inlinable
    public func withElement<R, E: Swift.Error>(
        at index: Index<Element>,
        _ body: (borrowing Element) throws(E) -> R
    ) throws(E) -> R {
        var thrown: E? = nil
        let result: R? = unsafe withUnsafePointer(to: _storage) { base in
            let address = unsafe Memory.Address(base)
            let ptr: Pointer<Element>.Immutable = address.pointer(at: index, stride: Self.slotStride, as: Element.self)
            do {
                return try body(ptr.pointee)
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

    /// Provides mutable access to the element at the given index via closure.
    ///
    /// - Parameters:
    ///   - index: The index of the element.
    ///   - body: A closure that receives a mutable reference to the element.
    /// - Returns: The value returned by the closure.
    /// - Precondition: The element at `index` must be initialized.
    @inlinable
    public mutating func withMutableElement<R, E: Swift.Error>(
        at index: Index<Element>,
        _ body: (inout Element) throws(E) -> R
    ) throws(E) -> R {
        var thrown: E? = nil
        let result: R? = unsafe withUnsafeMutablePointer(to: &_storage) { base in
            let address = unsafe Memory.Mutable.Address(base)
            let ptr: Pointer<Element>.Mutable = address.pointer(at: index, stride: Self.slotStride, as: Element.self)
            do {
                return try body(&ptr.pointee)
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

    // MARK: - Deinitialization

    /// Deinitializes elements from index 0 up to (but not including) count.
    ///
    /// - Parameter count: The number of elements to deinitialize.
    /// - Precondition: Elements at indices 0..<count must be initialized.
    /// - Note: Non-mutating to allow use from deinit contexts.
    @inlinable
    public func deinitialize(count: Index<Element>.Count) {
        _ = unsafe withUnsafePointer(to: _storage) { base in
            let address = unsafe Memory.Mutable.Address(UnsafeMutableRawPointer(mutating: base))
            (.zero..<count).forEach { index in
                unsafe address.pointer(at: index, stride: Self.slotStride, as: Element.self)
                    .base.deinitialize(count: 1)
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
            let address = unsafe Memory.Mutable.Address(UnsafeMutableRawPointer(mutating: base))
            range.forEach { index in
                unsafe address.pointer(at: index, stride: Self.slotStride, as: Element.self)
                    .base.deinitialize(count: 1)
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
    /// - Note: For full ring buffer support, use buffer-primitives which provides
    ///   `Buffer.Ring` discipline and `Storage.Inline+Cyclic` extensions.
    @inlinable
    public func deinitialize(head: Index<Element>, count: Index<Element>.Count) {
        guard count > .zero else { return }
        let cap = Index<Element>.Count(UInt(capacity))
        var index = head
        _ = unsafe withUnsafePointer(to: _storage) { base in
            let address = unsafe Memory.Mutable.Address(UnsafeMutableRawPointer(mutating: base))
            (.zero..<count).forEach { _ in
                unsafe address.pointer(at: index, stride: Self.slotStride, as: Element.self)
                    .base.deinitialize(count: 1)
                // Ring successor: (index + 1) % capacity
                index = (index + Index<Element>.Count.one) % cap
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
            unsafe heapStorage.withUnsafeMutablePointerToElements { destination in
                let address = unsafe Memory.Mutable.Address(base)
                (.zero..<count).forEach { index in
                    let source: Pointer<Element>.Mutable = address.pointer(at: index, stride: Self.slotStride, as: Element.self)
                    unsafe (destination + index).initialize(to: source.move())
                }
            }
        }
    }
}
