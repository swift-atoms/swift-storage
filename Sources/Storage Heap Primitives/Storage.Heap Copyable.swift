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

// MARK: - Copyable Extensions

extension Storage.Heap where Element: Copyable {
    /// Creates a copy of this storage with all initialized elements.
    ///
    /// Handles all initialization patterns (.empty, .one, .two).
    ///
    /// - Returns: A new storage instance with copied elements.
    @inlinable
    public func copy() -> Storage.Heap<Element> {
        let init_ = self.initialization
        let count = init_.count
        let new = Storage.Heap<Element>.create(minimumCapacity: count)
        new.initialization = .linear(count: count)

        guard count > .zero else { return new }

        func copySpan(_ span: Storage.Span, dstStart: inout Storage.Slot) {
            guard !span.isEmpty else { return }
            _ = unsafe withUnsafeMutablePointerToElements { src in
                unsafe new.withUnsafeMutablePointerToElements { dst in
                    var slot = span.start
                    while slot < span.end {
                        let srcOffset = Storage.Slot.Offset(fromZero: slot).retag(Element.self)
                        let dstOffset = Storage.Slot.Offset(fromZero: dstStart).retag(Element.self)
                        unsafe (dst + dstOffset).initialize(to: (src + srcOffset).pointee)
                        slot = slot.successor.saturating()
                        dstStart = dstStart.successor.saturating()
                    }
                }
            }
        }

        var dstSlot: Storage.Slot = .zero
        switch init_ {
        case .empty:
            break
        case .one(let span):
            copySpan(span, dstStart: &dstSlot)
        case .two(let first, let second):
            copySpan(first, dstStart: &dstSlot)
            copySpan(second, dstStart: &dstSlot)
        }

        return new
    }

    /// Copies all initialized elements to destination storage.
    ///
    /// Elements are copied to linear positions starting at slot 0 in the destination.
    /// Handles all initialization patterns (.empty, .one, .two).
    ///
    /// - Parameter destination: The destination storage.
    /// - Precondition: Destination must have sufficient capacity.
    @inlinable
    public func copy(to destination: Storage.Heap<Element>) {
        let init_ = self.initialization

        func copySpan(_ span: Storage.Span, dstStart: inout Storage.Slot) {
            guard !span.isEmpty else { return }
            _ = unsafe withUnsafeMutablePointerToElements { src in
                unsafe destination.withUnsafeMutablePointerToElements { dst in
                    var slot = span.start
                    while slot < span.end {
                        let srcOffset = Storage.Slot.Offset(fromZero: slot).retag(Element.self)
                        let dstOffset = Storage.Slot.Offset(fromZero: dstStart).retag(Element.self)
                        unsafe (dst + dstOffset).initialize(to: (src + srcOffset).pointee)
                        slot = slot.successor.saturating()
                        dstStart = dstStart.successor.saturating()
                    }
                }
            }
        }

        var dstSlot: Storage.Slot = .zero
        switch init_ {
        case .empty:
            break
        case .one(let span):
            copySpan(span, dstStart: &dstSlot)
        case .two(let first, let second):
            copySpan(first, dstStart: &dstSlot)
            copySpan(second, dstStart: &dstSlot)
        }
    }

    /// Copies elements in the given span to linear positions in the destination.
    ///
    /// Elements from the source span are placed at slots 0..<span.count in the
    /// destination storage.
    ///
    /// - Parameters:
    ///   - span: The contiguous range of slots to copy from.
    ///   - destination: The destination storage.
    /// - Precondition: All slots in the span must contain initialized elements.
    /// - Precondition: Destination slots 0..<span.count must be uninitialized.
    @inlinable
    public func copy(span: Storage.Span, to destination: Storage.Heap<Element>) {
        guard !span.isEmpty else { return }
        _ = unsafe withUnsafeMutablePointerToElements { src in
            unsafe destination.withUnsafeMutablePointerToElements { dst in
                var srcSlot = span.start
                var dstSlot: Storage.Slot = .zero
                while srcSlot < span.end {
                    let srcOffset = Storage.Slot.Offset(fromZero: srcSlot).retag(Element.self)
                    let dstOffset = Storage.Slot.Offset(fromZero: dstSlot).retag(Element.self)
                    unsafe (dst + dstOffset).initialize(to: (src + srcOffset).pointee)
                    srcSlot = srcSlot.successor.saturating()
                    dstSlot = dstSlot.successor.saturating()
                }
            }
        }
    }
}
