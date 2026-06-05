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

public import Index_Primitives
public import Memory_Heap_Primitives
public import Memory_Inline_Primitives
public import Storage_Primitive

extension Storage.Small where Element: ~Copyable {
    /// Creates storage sized for at least `minimumCapacity` elements.
    ///
    /// Starts inline when `minimumCapacity` fits the inline arm; otherwise allocates the
    /// heap arm directly (skipping the inline arm). Mirrors `Memory.Heap.create` so the
    /// buffer disciplines drive `Storage.Small` through the same growable-substrate surface.
    @inlinable
    public static func create(minimumCapacity: Index<Element>.Count) -> Self {
        if minimumCapacity <= Index<Element>.Count(UInt(inlineCapacity)) {
            Self(_storage: .inline(Memory.Inline<Element, inlineCapacity>()))
        } else {
            Self(_storage: .heap(Memory.Heap<Element>.create(minimumCapacity: minimumCapacity)))
        }
    }
}
