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
public import Storage_Primitive

// MARK: - Pinned pointer escape hatches (forwarders to the leaf)

extension Storage.Contiguous where Element: ~Copyable, Substrate == Memory.Heap<Element> {
    /// Returns a mutable pointer to the element at the given physical slot.
    ///
    /// The documented escape hatch ([MEM-SAFE-015]), forwarded to the leaf.
    /// See `Memory.Heap.pointer(at:)`.
    ///
    /// - Warning: The caller must ensure the slot is valid and within capacity.
    @unsafe
    @inlinable
    public func pointer(at slot: Index<Element>) -> UnsafeMutablePointer<Element> {
        unsafe _substrate.pointer(at: slot)
    }

    /// Returns an immutable pointer to the element at the given physical slot.
    ///
    /// - Warning: The caller must ensure the slot is valid and within capacity.
    @unsafe
    @inlinable
    @_disfavoredOverload
    public func pointer(at slot: Index<Element>) -> UnsafePointer<Element> {
        unsafe _substrate.pointer(at: slot)
    }
}
