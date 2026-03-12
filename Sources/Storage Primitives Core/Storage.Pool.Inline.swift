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

extension Storage.Pool where Element: ~Copyable {
    /// Static-capacity inline pool with bitmap-scanned per-slot reuse.
    ///
    /// `Storage<Element>.Pool.Inline<N>` is a stack-backed pool allocator for typed elements.
    /// It provides:
    /// - O(capacity) allocation via bitmap scanning (no in-band free list)
    /// - O(1) deallocation via bit flip
    /// - Per-slot reuse (bitmap-tracked)
    /// - `Index<Element>.Bounded<N>` for precondition-free pointer access
    ///
    /// Element cleanup is the consuming buffer type's responsibility.
    ///
    /// ## Design
    ///
    /// Uses bitmap scanning instead of in-band free list links:
    /// - Single source of truth (no inconsistent secondary structure)
    /// - No `Element` stride constraint (works with `UInt8`)
    /// - Acceptable performance for N ≤ 256 (at most 4 words to scan)
    ///
    /// ## Invariants
    ///
    /// - `capacity` is a compile-time constant in range `0...256`
    /// - `_slots` bit `i` is set iff slot `i` contains an allocated element
    /// - `_allocated == _slots.popcount` (cached for O(1) access)
    ///
    /// ## Usage
    ///
    /// ```swift
    /// var pool = Storage<Node>.Pool.Inline<16>()
    /// let slot = try pool.allocate()
    /// pool.pointer(at: slot).initialize(to: node)
    /// // ... use ...
    /// _ = pool.pointer(at: slot).move()
    /// try pool.deallocate(at: slot)
    /// ```
    public struct Inline<let capacity: Int>: ~Copyable {
        @_rawLayout(likeArrayOf: Element, count: capacity)
        @usableFromInline
        package struct _Raw: ~Copyable {
            @usableFromInline init() {}
        }

        @usableFromInline package var _storage: _Raw
        @usableFromInline package var _slots: Bit.Vector.Static<4>
        @usableFromInline package var _allocated: Index<Element>.Count

        /// Creates an empty inline pool with all slots unallocated.
        @inlinable
        public init() {
            precondition(capacity <= 256, "Storage.Pool.Inline capacity must be ≤256")
            _storage = _Raw()
            _slots = Bit.Vector.Static<4>()
            _allocated = .zero
        }
    }
}
