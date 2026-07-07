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

import Index_Primitives
public import Store_Initialization_Primitives
public import Store_Primitive

extension Store {
    /// Fixed-capacity **inline** typed storage — `n` `Element` slots laid out directly in the value's
    /// own footprint (`@_rawLayout(likeArrayOf: Element, count: n)`), with no heap allocation.
    ///
    /// `Store.Inline` is the inline column of the tower. It is **Allocation-INDEPENDENT** — it owns no
    /// allocation and carves no region; the bytes are part of the value — so it lives on the
    /// non-generic `Store` namespace (seat ruling 2026-06-09, consistent with `Store.Split` and the W2
    /// Allocation-independent → `Store` ruling), NOT phantom-nested under the `Storage<Allocation>`
    /// carrier.
    ///
    /// ## In-place access (no cached base)
    ///
    /// Because the bytes are inline, the base pointer is `withUnsafePointer(to: _storage)` — valid only
    /// while the value stays put. `Memory.Inline.base` escapes that pointer, so **caching it would
    /// dangle the instant the `~Copyable` value moves** (the B finding). Every accessor therefore
    /// recomputes the pointer per-operation, bounded by its own borrow of `self`; nothing is cached.
    ///
    /// Carries the `[MEM-SAFE-027]` `_deinitWorkaround` (swiftlang/swift#86652) as the FIRST stored
    /// property so the `@_rawLayout` storage (which MUST be LAST) is not misclassified as trivial and
    /// its `deinit` skipped across a package boundary. Unconditionally `~Copyable` so the deinit oracle
    /// is legal; conditional `Copyable` becomes the explicit `copy()`.
    @frozen
    public struct Inline<Element: ~Copyable, let n: Int>: ~Copyable {
        /// `[MEM-SAFE-027]` — forces non-trivial destruction so `deinit` is not skipped cross-package.
        ///
        /// MUST precede the `@_rawLayout` storage. Always `nil`.
        @usableFromInline
        internal var _deinitWorkaround: AnyObject? = nil

        /// The initialization ledger.
        ///
        /// The deinit oracle destroys exactly these slots.
        @usableFromInline
        internal var _initialization: Store.Initialization<Element>

        /// Inline raw storage: exactly `n` `Element`-sized cells in the value's footprint.
        ///
        /// `@_rawLayout` storage MUST be the LAST stored property.
        @_rawLayout(likeArrayOf: Element, count: n)
        @usableFromInline
        internal struct _Raw: ~Copyable {
            @usableFromInline
            internal init() {}
        }

        @usableFromInline
        internal var _storage: _Raw

        /// Creates empty inline storage of fixed capacity `n`.
        @inlinable
        public init() {
            self._deinitWorkaround = nil
            self._initialization = .empty
            self._storage = _Raw()
        }

        /// **The deinit oracle.**
        ///
        /// Destroys exactly the live elements per the ledger, in place — the
        /// base is recomputed inside this borrow (never cached), so the inline bytes are addressed at
        /// their current footprint.
        deinit {
            _initialization.forEach { range in
                guard !range.isEmpty else { return }
                unsafe withUnsafePointer(to: _storage) { raw in
                    let base = unsafe UnsafeMutableRawPointer(mutating: UnsafeRawPointer(raw))
                        .assumingMemoryBound(to: Element.self)
                    unsafe (base + Index<Element>.Offset(fromZero: range.lowerBound))
                        .deinitialize(count: range.count)
                }
            }
        }
    }
}
