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

public import Bit_Vector_Static_Primitives

extension Storage.Arena where Element: ~Copyable {
    /// Static-capacity inline arena with bump allocation and bulk reset.
    ///
    /// `Storage<Element>.Arena.Inline<N>` is a stack-backed bump allocator for typed elements.
    /// It provides:
    /// - O(1) allocation (sequential bump)
    /// - No individual deallocation
    /// - Bulk reset via `deinitialize.all()`
    /// - `Index<Element>.Bounded<N>` for precondition-free pointer access
    ///
    /// Element cleanup is the consuming buffer type's responsibility.
    ///
    /// ## Invariants
    ///
    /// - `capacity` is a compile-time constant in range `0...256`
    /// - `_slots` bit `i` is set iff slot `i` contains an allocated element
    /// - `_allocated == _slots.popcount` (cached for O(1) access)
    /// - Allocation is sequential: slots 0..<_allocated are allocated
    ///
    /// ## Usage
    ///
    /// ```swift
    /// var arena = Storage<Node>.Arena.Inline<16>()
    /// if let slot = arena.allocate() {
    ///     arena.pointer(at: slot).initialize(to: node)
    ///     // ... use ...
    /// }
    /// arena.deinitialize.all()
    /// ```
    public struct Inline<let capacity: Int>: ~Copyable {
        @_rawLayout(likeArrayOf: Element, count: capacity)
        @usableFromInline
        package struct _Raw: ~Copyable {
            @usableFromInline init() {}
        }

        @usableFromInline package var _slots: Bit.Vector.Static<4>
        @usableFromInline package var _allocated: Index<Element>.Count

        // NOTE: _storage MUST be the last stored property. See Storage.Inline
        // for the full explanation of the Swift 6.2.4 IRGen crash when fixed-size
        // fields follow a variable-size @_rawLayout field.
        @usableFromInline package var _storage: _Raw

        /// Creates an empty inline arena with all slots unallocated.
        @inlinable
        public init() {
            precondition(capacity <= 256, "Storage.Arena.Inline capacity must be ≤256")
            _slots = Bit.Vector.Static<4>()
            _allocated = .zero
            _storage = _Raw()
        }
    }
}
