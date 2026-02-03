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

import Index_Primitives

extension Storage {
    /// Canonical heap storage using ManagedBuffer.
    ///
    /// `Storage.Heap<Element>` is the primitive heap storage building block.
    /// It provides:
    /// - Contiguous element storage with ARC lifetime
    /// - Reference semantics with manual element lifecycle
    /// - Support for ~Copyable elements
    /// - Initialization tracking via ``Storage/Heap/Header``
    ///
    /// ## Initialization Tracking
    ///
    /// The storage tracks which slots are initialized via the `initialization`
    /// property. The deinit uses this information to correctly deinitialize
    /// only the initialized slots.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let storage = Storage.Heap<Int>.create(minimumCapacity: Storage.Slot.Count(10))
    /// storage.initialize(to: 42, at: .zero)
    /// let value = storage.move(at: .zero)
    /// ```
    public final class Heap<Element: ~Copyable>: ManagedBuffer<Storage.Heap<Element>.Header, Element> {
        deinit {
            func deinitialize(span: Storage.Span) {
                guard !span.isEmpty else { return }
                _ = unsafe withUnsafeMutablePointerToElements { elements in
                    var slot = span.start
                    while slot < span.end {
                        let offset = Slot.Offset(fromZero: slot).retag(Element.self)
                        unsafe (elements + offset).deinitialize(count: 1)
                        slot = slot.successor.saturating()
                    }
                }
            }

            switch header.initialization {
            case .empty:
                return
            case .one(let span):
                deinitialize(span: span)
            case .two(let first, let second):
                deinitialize(span: first)
                deinitialize(span: second)
            }
        }
    }
}
