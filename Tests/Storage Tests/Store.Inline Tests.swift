import Index
import Storage
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
        #expect(cap == Index<Int>.Count(4))
        #expect(empty)
    }

    @Test
    func `initialize subscript mutate move`() {
        Probe.reset()
        var s = Store.Inline<Item, 4>()
        s.initialize(at: 0, to: Item(7, value: 70))
        let v0 = s[0].value
        #expect(v0 == 70)
        s[0].bump()
        let v0b = s[0].value
        #expect(v0b == 71)
        let cnt = s.count
        #expect(cnt == Index<Item>.Count(1))
        let moved = s.move(at: 0)
        let mv = moved.value
        let dEmpty = Probe.destroyed.isEmpty
        #expect(mv == 71)
        #expect(dEmpty)
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
        }
        let ds = Probe.destroyedSorted
        #expect(ds == [1, 2, 3])
    }

    @Test
    func
        `move at every slot round trips without leaking or double freeing (F-001 pointer-escape regression)`()
    {

        Probe.reset()
        var s = Store.Inline<Item, 4>()
        s.initialize(at: 0, to: Item(101))
        s.initialize(at: 1, to: Item(102))
        s.initialize(at: 2, to: Item(103))
        s.initialize(at: 3, to: Item(104))

        let m3 = s.move(at: 3)
        let m0 = s.move(at: 0)
        let m2 = s.move(at: 2)
        let m1 = s.move(at: 1)
        let ids = [m3.id, m0.id, m2.id, m1.id]
        #expect(ids == [104, 101, 103, 102])
        let emptyBeforeDrop = Probe.destroyed.isEmpty
        #expect(emptyBeforeDrop)
        _ = consume m3
        _ = consume m0
        _ = consume m2
        _ = consume m1
        let destroyedAfterConsume = Probe.destroyedSorted
        #expect(destroyedAfterConsume == [101, 102, 103, 104])
        let cnt = s.count
        #expect(cnt == .zero)
    }

    @Test
    func
        `_isValidPrefixTailRemoval accepts only the tail on a prefix-shaped ledger (F-004 regression)`()
    {

        var s = Store.Inline<Int, 4>()
        s.initialize(at: 0, to: 10)
        s.initialize(at: 1, to: 11)
        s.initialize(at: 2, to: 12)

        let tail = Swift.Range<Index<Int>>(start: 2, count: .one)
        let notTail0 = Swift.Range<Index<Int>>(start: 0, count: .one)
        let notTail1 = Swift.Range<Index<Int>>(start: 1, count: .one)
        let tailIsValid = s._isValidPrefixTailRemoval(range: tail)
        let notTail0IsValid = s._isValidPrefixTailRemoval(range: notTail0)
        let notTail1IsValid = s._isValidPrefixTailRemoval(range: notTail1)
        #expect(tailIsValid)
        #expect(!notTail0IsValid)
        #expect(!notTail1IsValid)

        s.initialization = .two(
            first: Swift.Range<Index<Int>>(start: 2, count: .one),
            second: Swift.Range<Index<Int>>(start: 0, count: .one)
        )
        let notTail0IsValidWhenWrapped = s._isValidPrefixTailRemoval(range: notTail0)
        #expect(notTail0IsValidWhenWrapped)

        s.initialization = .linear(count: 3)
        _ = s.move(at: 2)
        _ = s.move(at: 1)
        _ = s.move(at: 0)
    }

    @Test
    func `move only elements ride the seam`() {

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
        }
        let ds = Probe2.destroyedSorted
        #expect(ds == [1, 2])
    }
}

private struct MoveOnly: ~Copyable {
    let id: Int
    deinit { Probe2.recordDestroy(id) }
}

private enum Probe2 {}

extension Probe2 {
    nonisolated(unsafe) static var _destroyed: [Int] = []
    static func reset() { unsafe _destroyed = [] }
    static func recordDestroy(_ id: Int) { unsafe _destroyed.append(id) }
    static var destroyedSorted: [Int] { unsafe _destroyed.sorted() }
}
