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

public import Memory_Unique_Primitives
public import Storage_Primitive

// MARK: - Copy-on-Write forwarding (conditional — where the substrate shares)
//
// `Storage.Contiguous` is copy-on-write exactly when its substrate is (the sharing
// leaves — `Memory.Heap` where elements are `Copyable`). The forward delegates to the
// leaf's occupancy-aware CoW primitive (the ledger and the elements deep-copy together,
// leaf-side — including disjoint `.two` ring layouts). Value-type substrates
// (`Memory.Inline`) never share and do NOT conform; the growable buffer disciplines gate
// their CoW mutation surface on `S: Memory.Unique.`Protocol`` (non-overlapping with the
// `~Copyable`-element surface by Swift specificity — no `@_disfavoredOverload`).

extension Storage.Contiguous where Element: Copyable, Substrate: Memory.Unique.`Protocol` {
    /// Whether this storage is the sole owner of its backing.
    @inlinable
    public var isUnique: Bool {
        mutating get { _substrate.isUnique }
    }

    /// Ensures sole ownership, deep-copying the initialized extent when shared.
    ///
    /// - Returns: `true` if a copy was made to restore uniqueness.
    @inlinable
    @discardableResult
    public mutating func ensureUnique() -> Bool {
        _substrate.ensureUnique()
    }
}

extension Storage.Contiguous: Memory.Unique.`Protocol`
where Element: Copyable, Substrate: Memory.Unique.`Protocol` {}
