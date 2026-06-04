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

extension Storage.Small where Element: ~Copyable {
    /// Reconstructs storage from a `_Representation` and an element count.
    ///
    /// The full-reassignment seat (`self = Self(_storage:count:)`) is how `~Copyable` enum
    /// payloads are mutated in place — destructure via `case .arm(var x)`, operate, then
    /// reassign the whole `self`. Reassigning the field alone would be a partial
    /// reinitialization of a consumed `self` (rejected by the borrow checker).
    @inlinable
    init(_storage: consuming _Representation, count: Int) {
        self._storage = _storage
        self._count = count
    }

    /// The number of initialized elements.
    @inlinable
    public var count: Index<Element>.Count {
        Index<Element>.Count(UInt(_count))
    }

    /// The total slot capacity currently available: `inlineCapacity` while inline, or the
    /// heap arm's capacity once spilled. Capacity is DYNAMIC — the spill is internal to the
    /// substrate, so a fixed-`inlineCapacity` `Small` still grows unboundedly via the heap arm.
    ///
    /// Witnesses `Store.Protocol`'s `capacity` requirement.
    @inlinable
    public var capacity: Index<Element>.Count {
        switch _storage {
        case .inline:
            Index<Element>.Count(UInt(inlineCapacity))
        case .heap(let heap):
            heap.capacity
        }
    }

    /// Whether storage has spilled from the inline arm to the heap arm.
    ///
    /// An implementation detail of the inline⊕heap strategy — `package` so tests and
    /// in-package disciplines can assert spill behavior without exposing it to consumers.
    @inlinable
    package var isSpilled: Bool {
        switch _storage {
        case .inline: false
        case .heap: true
        }
    }
}
