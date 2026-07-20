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

import Affine_Primitives_Standard_Library_Integration
public import Index_Primitives
import Ordinal_Primitives_Standard_Library_Integration
public import Store_Initialization_Primitives
public import Store_Protocol_Primitives

// MARK: - Properties

extension Store.Inline where Element: ~Copyable {
    /// Fixed inline capacity — the value-generic `n`.
    @inlinable
    public var capacity: Index<Element>.Count { Index<Element>.Count(UInt(n)) }

    /// Live occupancy — the ledger's initialized count.
    @inlinable
    public var count: Index<Element>.Count { _initialization.count }

    /// Whether no slots are initialized.
    @inlinable
    public var isEmpty: Bool { _initialization.isEmpty }

    /// The initialization ledger — settable so a composing discipline can bulk-sync it.
    @inlinable
    public var initialization: Store.Initialization<Element> {
        get { _initialization }
        set { _initialization = newValue }
    }
}

// MARK: - In-place base for the coroutine subscript ONLY (per-op, never cached)

// `initialize(at:to:)` / `move(at:)` below do ALL of their pointer arithmetic and dereference
// INSIDE the `withUnsafeMutablePointer` closure directly — the ratified
// `inline-storage-read-pointer-escape.md` pattern, mirroring the deinit oracle
// (`Store.Inline.swift:77-87`) — so those two ops have NO pointer escape at all.
//
// `subscript`'s `_read`/`_modify` cannot follow the same shape: Swift's coroutine `yield` is only
// recognized in the accessor's own immediate lexical body, not inside a nested closure literal —
// `unsafe withUnsafePointer(to: _storage) { raw in yield raw.pointee }` fails to compile
// ("cannot find 'yield' in scope"), confirmed against this toolchain while fixing this finding.
// `_read`/`_modify` are required here (not plain `get`/`set`) because the seam must support
// `~Copyable` `Element` without copying, so there is no closure-only alternative for the
// coroutine case. `_readBase()` / `_mutableBase()` therefore remain — narrowed to this ONE call
// site — as a bounded, DOCUMENTED exception: `withUnsafePointer(to:_:)` states "the pointer
// argument is valid only during the execution of withUnsafePointer(to:_:). Do not store or
// return the pointer for later use," and returning it here is against that letter. It is sound
// in practice because (1) `subscript`'s `_read`/`_modify` borrow `self` (shared or exclusive)
// for the coroutine's ENTIRE duration — Swift's own exclusivity enforcement forbids `self` from
// moving while suspended at `yield` — so the inline bytes' address cannot change between this
// call returning and the immediate dereference in the same accessor body; (2) the pointer is
// used exactly once, immediately, and is never cached across separate calls (recomputed fresh
// per access, per `Store.Inline.swift`'s documented invariant). This mirrors the DECISION
// document's own conclusion for the structurally-identical mutating `pointer(at:)` case ("this is
// still technically undefined behavior per Swift's documentation—it just happens to work in
// practice because... the caller typically uses the pointer immediately").
extension Store.Inline where Element: ~Copyable {
    /// The typed base for reading — recomputed within the caller's borrow of `self`; never cached.
    ///
    /// See the file-level note above: this is a bounded, documented exception to the
    /// no-escape rule, required only because `yield` cannot appear inside a nested closure.
    @inlinable
    package func _readBase() -> UnsafePointer<Element> {
        unsafe withUnsafePointer(to: _storage) {
            unsafe UnsafeRawPointer($0).assumingMemoryBound(to: Element.self)
        }
    }

    /// The typed base for mutation — recomputed within the caller's exclusive `&self` access.
    ///
    /// See the file-level note above: this is a bounded, documented exception to the
    /// no-escape rule, required only because `yield` cannot appear inside a nested closure.
    @inlinable
    package mutating func _mutableBase() -> UnsafeMutablePointer<Element> {
        unsafe withUnsafeMutablePointer(to: &_storage) {
            unsafe UnsafeMutableRawPointer($0).assumingMemoryBound(to: Element.self)
        }
    }
}

// MARK: - Store.Protocol seam (the 4 ops, over the in-place inline bytes)

extension Store.Inline where Element: ~Copyable {
    /// Reads or writes the initialized element at a physical slot (witnesses `subscript`).
    @inlinable
    public subscript(slot: Index<Element>) -> Element {
        _read {
            let pointer = unsafe _readBase() + Index<Element>.Offset(fromZero: slot)
            yield unsafe pointer.pointee
        }
        _modify {
            let pointer = unsafe _mutableBase() + Index<Element>.Offset(fromZero: slot)
            yield &(unsafe pointer.pointee)
        }
    }

    /// Initializes the uninitialized slot at `slot` (uninit → init; extends the linear-prefix ledger).
    @inlinable
    public mutating func initialize(at slot: Index<Element>, to element: consuming Element) {
        // NOTE: unlike `move(at:)` below, this cannot do its dereference inside the
        // `withUnsafeMutablePointer` closure — capturing an external `consuming Element`
        // parameter INTO a non-escaping stdlib closure hits Swift's ownership checker
        // ("'element' is borrowed and cannot be consumed" / "missing reinitialization of
        // closure capture 'element' after consume", both confirmed against this toolchain
        // while fixing this finding; `Element` is generic over `~Copyable`, so there is no
        // capture-list spelling available that both moves `element` in and satisfies the
        // checker). `_mutableBase()` is used instead — see its documented, bounded-exception
        // rationale above: the pointer is used exactly once, immediately, in the very next
        // statement, under the same exclusive `&self` access `_mutableBase()` itself borrows.
        let pointer = unsafe _mutableBase() + Index<Element>.Offset(fromZero: slot)
        unsafe pointer.initialize(to: element)
        _initialization = .linear(count: count + .one)
    }

    /// Moves the initialized element out of `slot` (init → uninit; shrinks the linear-prefix ledger).
    @inlinable
    public mutating func move(at slot: Index<Element>) -> Element {
        let element = unsafe withUnsafeMutablePointer(to: &_storage) { raw -> Element in
            let base = unsafe UnsafeMutableRawPointer(raw).assumingMemoryBound(to: Element.self)
            let pointer = unsafe base + Index<Element>.Offset(fromZero: slot)
            return unsafe pointer.move()
        }
        _initialization = .linear(count: count.subtract.saturating(.one))
        return element
    }
}

// MARK: - Ledger-aware removal (debug-asserted LIFO/tail removal)

// `Store.Protocol+Deinitialize.swift`'s generic `deinitialize(at:)` / `deinitialize(range:)`
// derivations are built ONLY on `move(at:)`, which self-maintains the ledger with
// UNCONDITIONAL linear-prefix arithmetic (`_initialization = .linear(count: count - 1)`) —
// truthful ONLY when the removed slot is the CURRENT tail of a prefix-shaped ledger (the LIFO
// discipline `swapAt`/`move(from:to:)`/`moveInitialize` rely on too, but those always pair every
// `move(at:)` with a corresponding `initialize(at:to:)` that restores the count, so their NET
// ledger effect stays truthful even though intermediate slots are arbitrary — deinitialize has
// no such pairing). Removing a NON-tail slot through the generic derivation silently falsifies
// the ledger: the vacated slot re-appears "initialized," and the real (untouched) tail slot
// silently drops off as "uninitialized." The deinit oracle honors that falsified ledger, so this
// is a drop-time UB footgun (double-deinitialize of already-uninitialized memory, or a leaked
// live tail element) even when the per-call precondition ("the element at `slot` must be
// initialized") was honestly satisfied.
//
// These concrete overrides shadow the generic derivation for direct `Store.Inline` call sites
// (Swift resolves a concrete type's own extension member over a less-specific protocol
// extension default): same bodies, plus a debug-only tail check that fires while the ledger is
// CURRENTLY prefix-shaped. A discipline that has already bulk-synced a non-prefix ledger
// (`Buffer.Ring`) is unaffected — `_isValidPrefixTailRemoval` is vacuously `true` once
// `isPrefixShaped` is `false`, matching that `Store.Ledgered.Protocol` owns its own resync.
//
// NOTE (disclosed scope limit): a generic algorithm written against the bare `Store.`Protocol``
// constraint (rather than directly against the concrete `Store.Inline` type) resolves
// `deinitialize(at:)`/`deinitialize(range:)` at the LESS-specific protocol extension — Swift's
// generic member lookup is resolved against the declared constraint, not the concrete runtime
// type — so this debug check does not reach that call path. See REPORT.md for the full
// discussion; a principal-level contract change (removing ledger self-maintenance from the seam
// ops in favor of mandatory explicit sync) is the alternative the brief names for closing that
// remaining gap, and is out of scope for this same-homes fix.
extension Store.Inline where Element: ~Copyable {
    /// Whether removing `removed` keeps a CURRENTLY prefix-shaped ledger truthful.
    ///
    /// Always `true` when the ledger is not currently prefix-shaped (a wrapped/offset
    /// discipline owns its own resync) or when `removed` is empty.
    @inlinable
    package func _isValidPrefixTailRemoval(range removed: Swift.Range<Index<Element>>) -> Bool {
        guard initialization.isPrefixShaped, !removed.isEmpty else { return true }
        return removed.upperBound == initialization.count.map(Ordinal.init)
    }

    /// Deinitializes the element at `slot`, leaving it uninitialized.
    ///
    /// - Parameter slot: The physical slot coordinate.
    /// - Precondition: The element at `slot` must be initialized. When the ledger is currently
    ///   prefix-shaped, `slot` must additionally be its tail (debug-asserted) — the only removal
    ///   position for which `move(at:)`'s self-maintenance stays truthful; see the file-level
    ///   note above.
    @inlinable
    public mutating func deinitialize(at slot: Index<Element>) {
        let removed = Swift.Range<Index<Element>>(start: slot, count: .one)
        assert(
            _isValidPrefixTailRemoval(range: removed),
            "Store.Inline.deinitialize(at:): slot is not the ledger's tail — move(at:)'s "
                + "linear-prefix self-maintenance is truthful only for LIFO (tail) removal; a "
                + "non-tail removal must re-sync `initialization` explicitly "
                + "(Store.Ledgered.Protocol)"
        )
        _ = move(at: slot)
    }

    /// Deinitializes every element in `range`, leaving each slot uninitialized.
    ///
    /// - Parameter range: The contiguous range of slots to deinitialize.
    /// - Precondition: Every slot in `range` must be initialized. When the ledger is currently
    ///   prefix-shaped, `range` must additionally equal its tail range (debug-asserted); see
    ///   ``deinitialize(at:)``.
    @inlinable
    public mutating func deinitialize(range: Swift.Range<Index<Element>>) {
        assert(
            _isValidPrefixTailRemoval(range: range),
            "Store.Inline.deinitialize(range:): range is not the ledger's tail range — "
                + "move(at:)'s linear-prefix self-maintenance is truthful only for LIFO (tail) "
                + "removal; a non-tail removal must re-sync `initialization` explicitly "
                + "(Store.Ledgered.Protocol)"
        )
        var slot = range.lowerBound
        while slot < range.upperBound {
            _ = move(at: slot)
            slot += .one
        }
    }
}

// MARK: - Conformance (the 4-op convenience seam)

// The four `where Element: ~Copyable` clauses in this file are the ASK-I fix (ratified
// 2026-06-10, REPORT-ADT-families-spike-findings.md F-6): the original bare extensions
// implicitly constrained the whole seam surface — conformance included — to
// `Element: Copyable` (the extension-implies-Copyable rule), silently excluding the
// move-only elements the declaration promises.
extension Store.Inline: Store.`Protocol` where Element: ~Copyable {}
