import Index
import Memory_Allocator_Primitive
import Memory_Heap
import Storage_Contiguous
import Testing

private typealias DenseStorage<Element: ~Copyable> =
    Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Element>

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
struct `Storage Contiguous Tests` {

    @Test
    func `near-limit capacity throws typed overflow instead of trapping`() {

        let nearLimit = Index<Int64>.Count(UInt(Int.max))
        #expect(throws: __StorageContiguousError.overflow(capacity: Int.max, stride: 8)) {
            _ = try DenseStorage<Int64>(minimumCapacity: nearLimit)
        }
    }

    @Test
    func `capacity above Int max throws typed overflow`() {
        let aboveIntMax = Index<Int64>.Count(UInt(Int.max) + 1)
        #expect(throws: __StorageContiguousError.self) {
            _ = try DenseStorage<Int64>(minimumCapacity: aboveIntMax)
        }
    }

    @Test
    func `throwing creation succeeds for a valid capacity`() throws {
        let s = try DenseStorage<Int>(minimumCapacity: Index<Int>.Count(4))
        let cap = s.capacity
        let empty = s.isEmpty
        #expect(cap == Index<Int>.Count(4))
        #expect(empty)
    }

    @Test
    func `create traps on byte-count overflow instead of overflowing arithmetic`() async {
        await #expect(processExitsWith: .failure) {
            _ = DenseStorage<Int64>.create(minimumCapacity: Index<Int64>.Count(UInt(Int.max)))
        }
    }

    @Test
    func `create reports capacity count empty`() {
        Probe.reset()
        let s = DenseStorage<Int>.create(minimumCapacity: Index<Int>.Count(4))
        let cap = s.capacity
        let cnt = s.count
        let empty = s.isEmpty
        #expect(cap == Index<Int>.Count(4))
        #expect(cnt == .zero)
        #expect(empty)
    }

    @Test
    func `initialize subscript mutate move`() {
        Probe.reset()
        var s = DenseStorage<Item>.create(minimumCapacity: Index<Item>.Count(4))
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
    func `span projects initialized prefix`() {
        Probe.reset()
        var s = DenseStorage<Item>.create(minimumCapacity: Index<Item>.Count(4))
        s.initialize(at: 0, to: Item(1, value: 10))
        s.initialize(at: 1, to: Item(2, value: 20))
        s.initialize(at: 2, to: Item(3, value: 30))
        let sp = s.span
        let spc = sp.count
        let v0 = sp[0].value
        let v2 = sp[2].value
        #expect(spc == 3)
        #expect(v0 == 10)
        #expect(v2 == 30)
    }

    @Test
    func `mutable span mutates in place`() {
        Probe.reset()
        var s = DenseStorage<Item>.create(minimumCapacity: Index<Item>.Count(4))
        s.initialize(at: 0, to: Item(1, value: 10))
        s.initialize(at: 1, to: Item(2, value: 20))
        do {
            let ms = s.mutableSpan
            ms[0].value = 111
            ms[1].bump()
        }
        let v0 = s[0].value
        let v1 = s[1].value
        #expect(v0 == 111)
        #expect(v1 == 21)
    }

    @Test
    func `output span append commits ledger`() {
        Probe.reset()
        var s = DenseStorage<Item>.create(minimumCapacity: Index<Item>.Count(4))
        s.outputSpan.append(Item(1, value: 100))
        s.outputSpan.append(Item(2, value: 200))
        let cnt = s.count
        let v0 = s[0].value
        let v1 = s[1].value
        #expect(cnt == Index<Item>.Count(2))
        #expect(v0 == 100)
        #expect(v1 == 200)
    }

    @Test
    func `with output span windows the tail exactly`() {
        Probe.reset()
        var s = DenseStorage<Item>.create(minimumCapacity: Index<Item>.Count(4))
        s.initialize(at: 0, to: Item(1, value: 10))
        var seenCapacity = -1
        var seenIsFull = false
        s.withOutputSpan(addingCapacity: Index<Item>.Count(2)) { span in
            seenCapacity = span.capacity
            span.append(Item(2, value: 20))
            span.append(Item(3, value: 30))
            seenIsFull = span.isFull
        }
        let cnt = s.count
        let v1 = s[1].value
        let v2 = s[2].value
        #expect(seenCapacity == 2)
        #expect(seenIsFull)
        #expect(cnt == Index<Item>.Count(3))
        #expect(v1 == 20)
        #expect(v2 == 30)

        var zeroCapacity = -1
        var zeroIsFull = false
        s.withOutputSpan(addingCapacity: .zero) { span in
            zeroCapacity = span.capacity
            zeroIsFull = span.isFull
        }
        let cntAfterZero = s.count
        #expect(zeroCapacity == 0)
        #expect(zeroIsFull)
        #expect(cntAfterZero == Index<Item>.Count(3))
    }

    @Test
    func `with output span commits partial appends on throw`() {
        Probe.reset()
        enum Deliberate: Swift.Error { case thrown }
        var s = DenseStorage<Item>.create(minimumCapacity: Index<Item>.Count(4))
        var didThrow = false
        do {
            try s.withOutputSpan(addingCapacity: Index<Item>.Count(3)) { span throws(Deliberate) in
                span.append(Item(1, value: 10))
                throw Deliberate.thrown
            }
        } catch {
            didThrow = true
        }
        let cnt = s.count
        let v0 = s[0].value
        #expect(didThrow)
        #expect(cnt == Index<Item>.Count(1))
        #expect(v0 == 10)
    }

    @Test
    func `teardown destroys live prefix once`() {
        Probe.reset()
        do {
            var s = DenseStorage<Item>.create(minimumCapacity: Index<Item>.Count(8))
            s.initialize(at: 0, to: Item(1))
            s.initialize(at: 1, to: Item(2))
            s.initialize(at: 2, to: Item(3))
        }
        let ds = Probe.destroyedSorted
        #expect(ds == [1, 2, 3])
    }

    @Test
    func
        `_isValidPrefixTailRemoval accepts only the tail on a prefix-shaped ledger (F-004 regression)`()
    {

        Probe.reset()
        var s = DenseStorage<Int>.create(minimumCapacity: Index<Int>.Count(4))
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
    func `copy deep copies live prefix`() {
        Probe.reset()
        var s = DenseStorage<Int>.create(minimumCapacity: Index<Int>.Count(4))
        s.initialize(at: 0, to: 7)
        s.initialize(at: 1, to: 8)
        let dup = s.copy()
        s[0] = 99
        let dup0 = dup[0]
        let dup1 = dup[1]
        let dupCount = dup.count
        let src0 = s[0]
        #expect(dup0 == 7)
        #expect(dup1 == 8)
        #expect(dupCount == Index<Int>.Count(2))
        #expect(src0 == 99)
    }

    @Test
    func
        `copy preserves a non-prefix ledger shape (F-002 regression: Buffer.Ring-style wrapped occupancy)`()
    {

        Probe.reset()
        var s = DenseStorage<Int>.create(minimumCapacity: Index<Int>.Count(6))
        for i in 0..<6 {
            s.initialize(at: Index<Int>(Ordinal(UInt(i))), to: i)
        }
        let wrapped = Store.Initialization<Int>.two(
            first: Index<Int>(Ordinal(UInt(4)))..<Index<Int>(Ordinal(UInt(6))),
            second: Index<Int>(Ordinal(UInt(0)))..<Index<Int>(Ordinal(UInt(2)))
        )
        s.initialization = wrapped
        let dup = s.copy()
        let dupInitialization = dup.initialization
        let dupCount = dup.count
        #expect(dupInitialization == wrapped)
        #expect(dupCount == Index<Int>.Count(4))
        let dup4 = dup[Index<Int>(Ordinal(UInt(4)))]
        let dup5 = dup[Index<Int>(Ordinal(UInt(5)))]
        let dup0 = dup[Index<Int>(Ordinal(UInt(0)))]
        let dup1 = dup[Index<Int>(Ordinal(UInt(1)))]
        #expect(dup4 == 4)
        #expect(dup5 == 5)
        #expect(dup0 == 0)
        #expect(dup1 == 1)
    }
}

private struct MoveOnlyElement: ~Copyable, Sendable {
    let id: Int
    init(_ id: Int) { self.id = id }
}

private func requireSendable<T: Sendable & ~Copyable>(_ value: borrowing T) {}

@Suite
struct `Storage Contiguous Sendable Tests` {

    @Test
    func `sendable admits move-only elements (W2-F1 regression)`() {
        let moveOnly = DenseStorage<MoveOnlyElement>.create(
            minimumCapacity: Index<MoveOnlyElement>.Count(1)
        )
        requireSendable(moveOnly)
        let copyable = DenseStorage<Int>.create(minimumCapacity: Index<Int>.Count(1))
        requireSendable(copyable)
        #expect(Bool(true))
    }
}
