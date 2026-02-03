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

// MARK: - Copyable Extensions for Inline Storage

extension Storage.Inline where Element: Copyable {
    /// Copies elements in span to linear positions in destination heap storage.
    ///
    /// Elements from the source span are placed at slots 0..<span.count in the
    /// destination storage.
    ///
    /// - Parameters:
    ///   - span: The contiguous range of slots to copy from.
    ///   - destination: The destination heap storage.
    /// - Precondition: All slots in the span must contain initialized elements.
    /// - Precondition: Destination slots 0..<span.count must be uninitialized.
    @inlinable
    public func copy(span: Storage.Span, to destination: Storage.Heap<Element>) {
        guard !span.isEmpty else { return }
        unsafe destination.withUnsafeMutablePointerToElements { dst in
            var srcSlot = span.start
            var dstSlot: Storage.Slot = .zero
            while srcSlot < span.end {
                let dstOffset = Storage.Slot.Offset(fromZero: dstSlot).retag(Element.self)
                unsafe (dst + dstOffset).initialize(to: pointer(at: srcSlot).pointee)
                srcSlot = srcSlot.successor.saturating()
                dstSlot = dstSlot.successor.saturating()
            }
        }
    }
}
