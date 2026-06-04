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
public import Storage_Primitive

extension Storage where Element: ~Copyable {
    /// A hybrid substrate that stores up to `inlineCapacity` elements inline (no
    /// allocation) and spills to a heap allocation when that capacity is exceeded.
    ///
    /// `Storage<Element>.Small<inlineCapacity>` is the second creatable substrate of the
    /// MSB capability tower (the first being `Memory.Heap`). It unifies the family of
    /// hand-rolled `.Small`/`.Inline` container variants into a single substrate that
    /// the buffer disciplines compose with zero new arity:
    /// `Buffer<Storage<Int>.Small<8>>.Linear`.
    ///
    /// ## Representation (the proven `_Representation` enum shape)
    ///
    /// Storage is a `~Copyable` discriminated union — never a two-field struct: mixing
    /// the inline store with the heap arm's class reference in one struct trips an LLVM
    /// release verifier crash ("Instruction does not dominate all uses!"); the enum
    /// destroys exactly one arm at a time. The enum payload holds ONLY the variable-size
    /// store — the fixed `_count` is a separate field (a bare fixed field beside the
    /// variable-size payload trips a 6.3.x `CopyPropagation` ownership miscompile).
    ///
    /// - `inline`: `InlineArray<inlineCapacity, Element?>` — compiler-managed slots where
    ///   `nil` marks an uninitialized slot (the Optional discriminant IS the per-slot
    ///   initialization ledger). No `@_rawLayout`, so the substrate may be conditionally
    ///   `Copyable` — lifting `INV-INLINE-004a` — and teardown is compiler-synthesized.
    /// - `heap`: `Memory.Heap<Element>` — the tower's class-backed leaf, reused as the
    ///   spill arm; it owns its own allocation and cleanup.
    ///
    /// ## Copyability
    ///
    /// `Storage.Small` is `Copyable` exactly when `Element` is, via the conditional
    /// extensions below. There is no user `deinit` anywhere — that is what keeps the
    /// conditional conformance legal under the `bd04f32` wall.
    public struct Small<let inlineCapacity: Int>: ~Copyable {
        /// The active storage arm. The enum (not a two-field struct) is
        /// release-correctness-load-bearing — see the type doc.
        @frozen
        @usableFromInline
        enum _Representation: ~Copyable {
            /// Inline arm: Optional slots; `nil` = uninitialized.
            case inline(InlineArray<inlineCapacity, Element?>)
            /// Heap arm: the tower's class-backed `Memory.Heap` leaf (the spill target).
            case heap(Memory.Heap<Element>)
        }

        @usableFromInline
        var _storage: _Representation

        /// The number of initialized elements. Stored SEPARATELY from `_storage` — a bare
        /// fixed field inside the variable-size enum payload trips a 6.3.x optimizer crash.
        @usableFromInline
        var _count: Int

        /// Creates empty inline storage (all `inlineCapacity` slots uninitialized).
        @inlinable
        public init() {
            _storage = .inline(InlineArray<inlineCapacity, Element?> { _ in nil })
            _count = 0
        }
    }
}

// MARK: - Conditional Copyable (lifts INV-INLINE-004a — restored by the compiler-managed inline arm)

extension Storage.Small._Representation: Copyable where Element: Copyable {}
extension Storage.Small: Copyable where Element: Copyable {}
