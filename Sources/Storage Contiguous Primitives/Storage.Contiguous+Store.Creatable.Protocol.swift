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

import Affine_Primitives_Standard_Library_Integration
public import Index_Primitives
public import Memory_Heap_Primitives
import Ordinal_Primitives_Standard_Library_Integration
public import Storage_Primitive
public import Store_Creatable_Primitives

// MARK: - Store.Creatable.Protocol conformance (heap-backed)

/// A heap-backed `Storage.Contiguous` is a creatable store: it vends
/// `create(minimumCapacity:)` (`Storage.Heap ~Copyable.swift`) and overrides the
/// element-wise relocation default with a bulk move over its single contiguous
/// region — preserving the realloc fast-path the growable buffers have always had,
/// now reached through the `Store.Creatable` capability rather than a pinned
/// same-type constraint.
extension Storage.Contiguous: Store.Creatable.`Protocol`
where Element: ~Copyable, Substrate == Memory.Heap<Element> {

    @inlinable
    public mutating func moveInitializePrefix(count: Index<Element>.Count, into destination: inout Self) {
        guard count > .zero else { return }
        let start: Index<Element> = .zero
        move(range: start..<count.map(Ordinal.init), to: destination)
    }
}
