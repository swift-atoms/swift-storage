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

// MARK: - Conformance (the 4-op convenience seam)

// The four `where Element: ~Copyable` clauses in this file are the ASK-I fix (ratified
// 2026-06-10, REPORT-ADT-families-spike-findings.md F-6): the original bare extensions
// implicitly constrained the whole seam surface — conformance included — to
// `Element: Copyable` (the extension-implies-Copyable rule), silently excluding the
// move-only elements the declaration promises.
extension Store.Inline: Store.`Protocol` where Element: ~Copyable {}
