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

public import Memory_Heap_Primitives
public import Memory_Inline_Primitives
public import Storage_Primitive

extension Storage where Element: ~Copyable {
    /// A hybrid substrate that stores up to `inlineCapacity` elements inline (no
    /// allocation) and spills to a heap allocation when that capacity is exceeded.
    ///
    /// `Storage<Element>.Small<inlineCapacity>` is the second creatable substrate of the
    /// MSB capability tower (the first being `Memory.Heap`). It unifies the family of
    /// hand-rolled `.Small`/`.Inline` container variants into a single storage substrate
    /// the buffer disciplines compose with zero new arity:
    /// `Buffer<Storage<Int>.Small<8>>.Linear`.
    ///
    /// ## Representation (the proven `_Representation` enum shape)
    ///
    /// Storage is a `~Copyable` discriminated union — never a two-field struct: mixing the
    /// `@_rawLayout` inline arm with the heap arm's class reference in one struct trips an
    /// LLVM release verifier crash ("Instruction does not dominate all uses!"); the enum
    /// destroys exactly one arm at a time. Each arm is an existing, seam-proven substrate,
    /// so `Storage.Small` is the per-container generalization of the buffer-tier
    /// `Buffer.{Linear,Ring}.Small._Representation` shape relocated down to the storage tier:
    ///
    /// - `inline`: `Memory.Inline<Element, inlineCapacity>` — fixed-capacity inline storage
    ///   (`@_rawLayout` + a `Store.Initialization` ledger), the inline twin of `Memory.Heap`.
    /// - `heap`: `Memory.Heap<Element>` — the tower's class-backed leaf, reused as the spill
    ///   target; it owns its own allocation and cleanup.
    ///
    /// ## Copyability
    ///
    /// `Storage.Small` is unconditionally `~Copyable` (`INV-INLINE-004a`: the `@_rawLayout`
    /// inline arm is unconditionally `~Copyable`). This matches every variant it absorbs —
    /// all of which are `~Copyable` today — so the unification is capability-preserving. A
    /// conditionally-`Copyable` `Small` is a documented FUTURE enhancement (see
    /// `Research/storage-small-substrate.md` "REVISION v1.0.1"), gated on the `INV-INLINE-004a`
    /// lift; it is deliberately not taken here because the Optional-slot representation it
    /// requires fights the typed-`Index`/raw-pointer `Store` seam.
    public struct Small<let inlineCapacity: Int>: ~Copyable {
        /// The active storage arm. The enum (not a two-field struct) is
        /// release-correctness-load-bearing — see the type doc.
        @frozen
        @usableFromInline
        enum _Representation: ~Copyable {
            /// Inline arm: the `@_rawLayout` + `Store.Initialization`-ledger fixed-capacity leaf.
            case inline(Memory.Inline<Element, inlineCapacity>)
            /// Heap arm: the tower's class-backed `Memory.Heap` leaf (the spill target).
            case heap(Memory.Heap<Element>)
        }

        @usableFromInline
        var _storage: _Representation

        /// Creates empty inline storage.
        @inlinable
        public init() {
            _storage = .inline(Memory.Inline<Element, inlineCapacity>())
        }
    }
}
