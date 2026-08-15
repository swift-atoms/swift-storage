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
public import Store_Primitive

extension Store {
    /// Describes which physical slots of an element store are initialized.
    ///
    /// `Store.Ledgered.`Protocol`` conformers vend this ledger via the settable
    /// `initialization` requirement, and a ledgered store's OWN teardown honors it —
    /// iterating these spans to clean up exactly the initialized slots, regardless of
    /// the discipline composed above.
    ///
    /// ## Cases
    ///
    /// - `empty`: No slots are initialized
    /// - `one`: A single contiguous range of initialized slots
    /// - `two`: Two disjoint ranges (for example, a wrapped ring buffer)
    ///
    /// ## Invariants
    ///
    /// - `.two` spans are sorted by start: `first.start < second.start`
    /// - `.two` spans are disjoint: `first.end <= second.start`
    ///
    /// ## Example: Ring Buffer Wrapping
    ///
    /// A ring buffer with capacity 8, head at slot 6, and 5 elements:
    /// ```
    /// Slots: [0][1][2][3][4][5][6][7]
    /// Data:   X  X  X  -  -  -  X  X
    ///         └──┴──┘           └──┴── initialized
    /// ```
    /// Initialization: `.two(first: [0,3), second: [6,8))`
    ///
    /// > Relocated from `Storage<Element>.Initialization` by the storage/memory
    /// > split (`swift-institute/Research/storage-memory-split.md` §2, seat-ratified
    /// > 2026-06-04); the storage-tier spelling remains available as a typealias.
    public enum Initialization<Element: ~Copyable & ~Escapable>: Sendable, Equatable {
        /// No slots are initialized.
        case empty

        /// A single contiguous range of initialized slots.
        case one(Swift.Range<Index_Primitives.Index<Element>>)

        /// Two disjoint ranges of initialized slots.
        ///
        /// Invariants:
        /// - `first.start < second.start`
        /// - `first.end <= second.start`
        case two(
            first: Swift.Range<Index_Primitives.Index<Element>>,
            second: Swift.Range<Index_Primitives.Index<Element>>
        )
    }
}
