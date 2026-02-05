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
    /// let storage = Storage.Heap<Int>.create(minimumCapacity: Index<Int>.Count(10))
    /// storage.initialize(to: 42, at: .zero)
    /// let value = storage.move(at: .zero)
    /// ```
    public final class Heap<Element: ~Copyable>: ManagedBuffer<Storage.Heap<Element>.Header, Element> {
        deinit {
            func deinitialize(range: Swift.Range<Index<Element>>) {
                guard !range.isEmpty else { return }
                _ = unsafe withUnsafeMutablePointerToElements { elements in
                    let offset = Index<Element>.Offset(fromZero: range.lowerBound)
                    unsafe (elements + offset).deinitialize(count: range.count)
                }
            }

            switch header.initialization {
            case .empty:
                return
            case .one(let range):
                deinitialize(range: range)
            case .two(let first, let second):
                deinitialize(range: first)
                deinitialize(range: second)
            }
        }
    }
}
