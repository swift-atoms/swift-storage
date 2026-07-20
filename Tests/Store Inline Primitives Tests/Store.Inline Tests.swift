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

// Behavioral tests for `Store.Inline<Element, n>` — fixed-capacity inline typed storage with in-place
// (never-cached) `@_rawLayout` access, the `Store.Initialization` ledger, the 4-op seam, and the
// deinit oracle. ONE `@Suite(.serialized)` for the shared destruction recorder.

import Index_Primitives
import Store_Inline_Primitives
import Testing

private final class Item: @unchecked Sendable {
    let id: Int
    var value: Int
    init(_ id: Int, value: Int = 0) {
        self.id = id
        self.value = value
    }
    deinit { Probe.recordDestroy(id) }
}

extension Item {
    func bump() { value += 1 }
}

private enum Probe {}

extension Probe {
    nonisolated(unsafe) static var _destroyed: [Int] = []
    static func reset() { unsafe _destroyed = [] }
    static func recordDestroy(_ id: Int) { unsafe _destroyed.append(id) }
    static var destroyed: [Int] { unsafe _destroyed }
    static var destroyedSorted: [Int] { unsafe _destroyed.sorted() }
}

@Suite(.serialized)
struct `Store Inline Tests` {

    @Test
    func `create reports capacity empty`() {
        let s = Store.Inline<Int, 4>()
        let cap = s.capacity
        let empty = s.isEmpty
        #expect(cap == Index<Int>.Count(4))  // capacity is the value-generic n
        #expect(empty)
    }

    @Test
    func `initialize subscript mutate move`() {
        Probe.reset()
        var s = Store.Inline<Item, 4>()
        s.initialize(at: 0, to: Item(7, value: 70))  // into the inline footprint
        let v0 = s[0].value
        #expect(v0 == 70)
        s[0].bump()  // _modify in place (per-op base)
        let v0b = s[0].value
        #expect(v0b == 71)
        let cnt = s.count
        #expect(cnt == Index<Item>.Count(1))
        let moved = s.move(at: 0)
        let mv = moved.value
        let dEmpty = Probe.destroyed.isEmpty
        #expect(mv == 71)
        #expect(dEmpty)  // moved out, not destroyed
        _ = consume moved
        let dAfter = Probe.destroyed
        #expect(dAfter == [7])
    }

    @Test
    func `teardown destroys live prefix once`() {
        Probe.reset()
        do {
            var s = Store.Inline<Item, 8>()
            s.initialize(at: 0, to: Item(1))
            s.initialize(at: 1, to: Item(2))
            s.initialize(at: 2, to: Item(3))
        }  // the in-place oracle destroys [0,3) → 1,2,3
        let ds = Probe.destroyedSorted
        #expect(ds == [1, 2, 3])
    }

    @Test
    func `move at every slot round trips without leaking or double freeing (F-001 pointer-escape regression)`() {
        // F-001: `move(at:)` computed its typed base via a helper (`_mutableBase()`) that
        // returned the pointer FROM `withUnsafeMutablePointer`'s closure — the escape the
        // package's own `inline-storage-read-pointer-escape.md` DECISION forbids. The fix moves
        // `move(at:)`'s pointer arithmetic AND dereference fully inside the closure (mirroring
        // the deinit oracle), so the pointer never leaves `withUnsafeMutablePointer`'s scope.
        // This exercises `move(at:)` at every physical slot (first, middle, last) with a
        // heap-referencing element: if the restructured pointer computation ever addressed the
        // wrong slot, this would show up as a wrong id moved, a double-destroy, or a leak (an id
        // missing from `destroyedSorted`).
        Probe.reset()
        var s = Store.Inline<Item, 4>()
        s.initialize(at: 0, to: Item(101))
        s.initialize(at: 1, to: Item(102))
        s.initialize(at: 2, to: Item(103))
        s.initialize(at: 3, to: Item(104))
        // Move out of every slot in a non-sequential order to stress the per-op base
        // recomputation (never cached across calls).
        let m3 = s.move(at: 3)
        let m0 = s.move(at: 0)
        let m2 = s.move(at: 2)
        let m1 = s.move(at: 1)
        let ids = [m3.id, m0.id, m2.id, m1.id]
        #expect(ids == [104, 101, 103, 102])
        let emptyBeforeDrop = Probe.destroyed.isEmpty  // moved out, not yet destroyed
        #expect(emptyBeforeDrop)
        _ = consume m3
        _ = consume m0
        _ = consume m2
        _ = consume m1
        let destroyedAfterConsume = Probe.destroyedSorted
        #expect(destroyedAfterConsume == [101, 102, 103, 104])  // exactly once each, no leaks
        let cnt = s.count
        #expect(cnt == .zero)
    }

    @Test
    func `_isValidPrefixTailRemoval accepts only the tail on a prefix-shaped ledger (F-004 regression)`() {
        // F-004: deinitialize(at:)/deinitialize(range:) are built only on move(at:), which
        // self-maintains the ledger with unconditional linear-prefix arithmetic — truthful only
        // when the removed slot is the CURRENT tail. This directly exercises the new debug-guard
        // decision logic (`_isValidPrefixTailRemoval`) that catches a non-tail removal before it
        // can silently falsify the ledger.
        var s = Store.Inline<Int, 4>()
        s.initialize(at: 0, to: 10)
        s.initialize(at: 1, to: 11)
        s.initialize(at: 2, to: 12)
        // Ledger is .one(0..<3) — prefix-shaped; the tail is slot 2.
        let tail = Swift.Range<Index<Int>>(start: 2, count: .one)
        let notTail0 = Swift.Range<Index<Int>>(start: 0, count: .one)
        let notTail1 = Swift.Range<Index<Int>>(start: 1, count: .one)
        let tailIsValid = s._isValidPrefixTailRemoval(range: tail)
        let notTail0IsValid = s._isValidPrefixTailRemoval(range: notTail0)
        let notTail1IsValid = s._isValidPrefixTailRemoval(range: notTail1)
        #expect(tailIsValid)
        #expect(!notTail0IsValid)
        #expect(!notTail1IsValid)
        // Once the ledger is no longer (currently) prefix-shaped, the guard steps aside — a
        // composing discipline that already bulk-synced a non-prefix shape owns its own resync.
        s.initialization = .two(
            first: Swift.Range<Index<Int>>(start: 2, count: .one),
            second: Swift.Range<Index<Int>>(start: 0, count: .one)
        )
        let notTail0IsValidWhenWrapped = s._isValidPrefixTailRemoval(range: notTail0)
        #expect(notTail0IsValidWhenWrapped)
        // Clean up without tripping any guard: reset to a plain prefix and drain from the tail.
        s.initialization = .linear(count: 3)
        _ = s.move(at: 2)
        _ = s.move(at: 1)
        _ = s.move(at: 0)
    }

    @Test
    func `move only elements ride the seam`() {
        // The ASK-I restoration (ratified 2026-06-10): the seam surface was silently
        // `Element: Copyable`-only via bare extensions; move-only elements are the
        // declaration's promise and must ride initialize/subscript/move + the oracle.
        Probe2.reset()
        do {
            var s = Store.Inline<MoveOnly, 4>()
            s.initialize(at: 0, to: MoveOnly(id: 1))
            s.initialize(at: 1, to: MoveOnly(id: 2))
            let borrowedID = s[0].id
            #expect(borrowedID == 1)
            let cnt = s.count
            #expect(cnt == Index<MoveOnly>.Count(2))
            let moved = s.move(at: 1)
            let movedID = moved.id
            #expect(movedID == 2)
            _ = consume moved
            let mid = Probe2.destroyedSorted
            #expect(mid == [2])
        }  // the oracle destroys the remaining live prefix slot
        let ds = Probe2.destroyedSorted
        #expect(ds == [1, 2])
    }
}

private struct MoveOnly: ~Copyable {
    let id: Int
    deinit { Probe2.recordDestroy(id) }
}

/// Separate recorder (per-suite isolation discipline; `MoveOnly` is used only by the
/// move-only test but a distinct recorder keeps the destruction streams independent).
private enum Probe2 {}

extension Probe2 {
    nonisolated(unsafe) static var _destroyed: [Int] = []
    static func reset() { unsafe _destroyed = [] }
    static func recordDestroy(_ id: Int) { unsafe _destroyed.append(id) }
    static var destroyedSorted: [Int] { unsafe _destroyed.sorted() }
}
