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

import Store_Inline_Primitives
import Index_Primitives
import Testing

private final class Item: @unchecked Sendable {
    let id: Int
    var value: Int
    init(_ id: Int, value: Int = 0) { self.id = id; self.value = value }
    func bump() { value += 1 }
    deinit { Probe.recordDestroy(id) }
}

private enum Probe {
    nonisolated(unsafe) static var _destroyed: [Int] = []
    static func reset() { unsafe _destroyed = [] }
    static func recordDestroy(_ id: Int) { unsafe _destroyed.append(id) }
    static var destroyed: [Int] { unsafe _destroyed }
    static var destroyedSorted: [Int] { unsafe _destroyed.sorted() }
}

@Suite(.serialized)
struct StoreInlineTests {

    @Test
    func createReportsCapacityEmpty() {
        let s = Store.Inline<Int, 4>()
        let cap = s.capacity, empty = s.isEmpty
        #expect(cap == Index<Int>.Count(4))           // capacity is the value-generic n
        #expect(empty)
    }

    @Test
    func initializeSubscriptMutateMove() {
        Probe.reset()
        var s = Store.Inline<Item, 4>()
        s.initialize(at: 0, to: Item(7, value: 70))   // into the inline footprint
        let v0 = s[0].value
        #expect(v0 == 70)
        s[0].bump()                                    // _modify in place (per-op base)
        let v0b = s[0].value
        #expect(v0b == 71)
        let cnt = s.count
        #expect(cnt == Index<Item>.Count(1))
        let moved = s.move(at: 0)
        let mv = moved.value
        let dEmpty = Probe.destroyed.isEmpty
        #expect(mv == 71)
        #expect(dEmpty)                                // moved out, not destroyed
        _ = consume moved
        let dAfter = Probe.destroyed
        #expect(dAfter == [7])
    }

    @Test
    func teardownDestroysLivePrefixOnce() {
        Probe.reset()
        do {
            var s = Store.Inline<Item, 8>()
            s.initialize(at: 0, to: Item(1))
            s.initialize(at: 1, to: Item(2))
            s.initialize(at: 2, to: Item(3))
        }   // the in-place oracle destroys [0,3) → 1,2,3
        let ds = Probe.destroyedSorted
        #expect(ds == [1, 2, 3])
    }

    @Test
    func moveOnlyElementsRideTheSeam() {
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
        }   // the oracle destroys the remaining live prefix slot
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
private enum Probe2 {
    nonisolated(unsafe) static var _destroyed: [Int] = []
    static func reset() { unsafe _destroyed = [] }
    static func recordDestroy(_ id: Int) { unsafe _destroyed.append(id) }
    static var destroyedSorted: [Int] { unsafe _destroyed.sorted() }
}
