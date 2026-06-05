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
public import Storage_Inline_Primitives
public import Storage_Primitive

extension Storage.Small where Element: ~Copyable {
    /// Reconstructs storage from a `_Representation` and an element count.
    ///
    /// The full-reassignment seat (`self = Self(_storage:count:)`) is how `~Copyable` enum
    /// payloads are mutated in place — destructure via `case .arm(var x)`, operate, then
    /// reassign the whole `self`. Reassigning the field alone would be a partial
    /// reinitialization of a consumed `self` (rejected by the borrow checker).
    @inlinable
    init(_storage: consuming _Representation) {
        self._storage = _storage
    }

    /// The total slot capacity currently available — DYNAMIC: the inline arm's fixed
    /// capacity while inline, or the heap arm's capacity once spilled. The spill is
    /// substrate-internal, so a fixed-`inlineCapacity` `Small` still grows unboundedly.
    ///
    /// Witnesses `Store.Protocol`'s `capacity` requirement by delegating to the active arm.
    @inlinable
    public var capacity: Index<Element>.Count {
        switch _storage {
        case .inline(let arm):
            arm.capacity
        case .heap(let arm):
            arm.capacity
        }
    }

    /// Whether storage has spilled from the inline arm to the heap arm.
    ///
    /// Spill-state is a substrate-local property: only `Storage.Small` has a spill concept,
    /// so it lives here, never on the neutral `Storage.Protocol` seam. `public` so consumers of
    /// the inline⊕heap substrate (and the buffers composed over it) can query spill behavior.
    @inlinable
    public var isSpilled: Bool {
        switch _storage {
        case .inline: false
        case .heap: true
        }
    }
}
