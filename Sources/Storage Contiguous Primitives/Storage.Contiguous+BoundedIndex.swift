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

public import Finite_Bounded_Primitives
public import Index_Primitives
public import Storage_Primitive

// MARK: - Bounded-index convenience (the fixed-capacity .Inline / .Static call surface)
//
// The `Buffer.{Linear,Ring}.Inline` fixed-capacity helpers (and the `.Static` consumers) address
// slots by a compile-time-bounded index `Index<Element>.Bounded<capacity>`. These overloads accept
// the bounded index and forward to the Store seam — the call surface the dissolved `Storage.Inline`
// used to vend directly, now provided generically over any contiguous substrate (e.g. a
// `Memory.Inline`-backed one).

extension Storage.Contiguous where Element: ~Copyable, Substrate: ~Copyable {
    /// Initializes the slot at the given bounded index — forwards to the Store seam.
    @inlinable
    public mutating func initialize<let capacity: Int>(
        to element: consuming Element,
        at slot: Index<Element>.Bounded<capacity>
    ) {
        initialize(at: Index<Element>(slot), to: element)
    }

    /// Moves the element out of the slot at the given bounded index — forwards to the Store seam.
    @inlinable
    public mutating func move<let capacity: Int>(at slot: Index<Element>.Bounded<capacity>) -> Element {
        move(at: Index<Element>(slot))
    }

    /// Deinitializes the slot at the given bounded index — move-and-discard over the Store seam
    /// (`deinitialize` is not on the neutral 4-op seam; `move` + drop is the equivalent).
    @inlinable
    public mutating func deinitialize<let capacity: Int>(at slot: Index<Element>.Bounded<capacity>) {
        _ = move(at: Index<Element>(slot))
    }
}
