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

// Behavioral-preservation tests for the reshaped `Storage<Allocation>.Contiguous<Element>` — typed
// `Index<Element>`, the `Store.Initialization` ledger, Span / MutableSpan / OutputSpan, the seam
// (initialize / subscript / move), explicit `copy()`, and the deinit oracle.
//
// ONE top-level `@Suite(.serialized)` wraps the Probe-using tests so their deferred teardown drops
// run serially against the shared destruction recorder (the binding deterministic-gate rule —
// cross-suite parallelism would corrupt the exact destruction counts). Tower values are `~Copyable`,
// so every property / subscript result is read into a copyable local before `#expect`.

import Storage_Contiguous_Primitives
import Memory_Heap_Primitives
import Memory_Allocator_Primitive
import Index_Primitives
import Testing

/// The canonical dense storage spelling: contiguous typed slots over a heap passthrough allocation.
private typealias DenseStorage<Element: ~Copyable> =
    Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<Element>

/// A class element whose `deinit` records its id — lets a test observe the deinit oracle.
private final class Item: @unchecked Sendable {
    let id: Int
    var value: Int
    init(_ id: Int, value: Int = 0) { self.id = id; self.value = value }
    func bump() { value += 1 }
    deinit { Probe.recordDestroy(id) }
}

/// Serialized destruction recorder (safe because the suite below is `.serialized`; the
/// `nonisolated(unsafe)` access is encapsulated here so call sites stay clean).
private enum Probe {
    nonisolated(unsafe) static var _destroyed: [Int] = []
    static func reset() { unsafe _destroyed = [] }
    static func recordDestroy(_ id: Int) { unsafe _destroyed.append(id) }
    static var destroyed: [Int] { unsafe _destroyed }
    static var destroyedSorted: [Int] { unsafe _destroyed.sorted() }
}

@Suite(.serialized)
struct StorageContiguousTests {

    @Test
    func createReportsCapacityCountEmpty() {
        Probe.reset()
        let s = DenseStorage<Int>.create(minimumCapacity: Index<Int>.Count(4))
        let cap = s.capacity, cnt = s.count, empty = s.isEmpty
        #expect(cap == Index<Int>.Count(4))
        #expect(cnt == .zero)
        #expect(empty)
    }

    @Test
    func initializeSubscriptMutateMove() {
        Probe.reset()
        var s = DenseStorage<Item>.create(minimumCapacity: Index<Item>.Count(4))
        s.initialize(at: 0, to: Item(7, value: 70))   // uninit → init (typed Index<Element>)
        let v0 = s[0].value                            // _read borrow
        #expect(v0 == 70)
        s[0].bump()                                    // _modify in place
        let v0b = s[0].value
        #expect(v0b == 71)
        let cnt = s.count
        #expect(cnt == Index<Item>.Count(1))
        let moved = s.move(at: 0)                       // init → uninit (consuming move OUT)
        let mv = moved.value
        let dEmpty = Probe.destroyed.isEmpty           // moved out, not destroyed
        #expect(mv == 71)
        #expect(dEmpty)
        _ = consume moved
        let dAfter = Probe.destroyed
        #expect(dAfter == [7])
    }

    @Test
    func spanProjectsInitializedPrefix() {
        Probe.reset()
        var s = DenseStorage<Item>.create(minimumCapacity: Index<Item>.Count(4))
        s.initialize(at: 0, to: Item(1, value: 10))
        s.initialize(at: 1, to: Item(2, value: 20))
        s.initialize(at: 2, to: Item(3, value: 30))
        let sp = s.span
        let spc = sp.count, v0 = sp[0].value, v2 = sp[2].value
        #expect(spc == 3)
        #expect(v0 == 10)
        #expect(v2 == 30)
    }

    @Test
    func mutableSpanMutatesInPlace() {
        Probe.reset()
        var s = DenseStorage<Item>.create(minimumCapacity: Index<Item>.Count(4))
        s.initialize(at: 0, to: Item(1, value: 10))
        s.initialize(at: 1, to: Item(2, value: 20))
        do {
            let ms = s.mutableSpan
            ms[0].value = 111
            ms[1].bump()
        }
        let v0 = s[0].value, v1 = s[1].value
        #expect(v0 == 111)
        #expect(v1 == 21)
    }

    @Test
    func outputSpanAppendCommitsLedger() {
        Probe.reset()
        var s = DenseStorage<Item>.create(minimumCapacity: Index<Item>.Count(4))
        s.outputSpan.append(Item(1, value: 100))       // bulk-init through the OutputSpan tail
        s.outputSpan.append(Item(2, value: 200))
        let cnt = s.count, v0 = s[0].value, v1 = s[1].value
        #expect(cnt == Index<Item>.Count(2))
        #expect(v0 == 100)
        #expect(v1 == 200)
    }

    @Test
    func teardownDestroysLivePrefixOnce() {
        Probe.reset()
        do {
            var s = DenseStorage<Item>.create(minimumCapacity: Index<Item>.Count(8))
            s.initialize(at: 0, to: Item(1))
            s.initialize(at: 1, to: Item(2))
            s.initialize(at: 2, to: Item(3))
        }   // the oracle destroys [0,3) → 1,2,3; then the heap region frees once
        let ds = Probe.destroyedSorted
        #expect(ds == [1, 2, 3])
    }

    @Test
    func copyDeepCopiesLivePrefix() {
        Probe.reset()
        var s = DenseStorage<Int>.create(minimumCapacity: Index<Int>.Count(4))
        s.initialize(at: 0, to: 7)
        s.initialize(at: 1, to: 8)
        let dup = s.copy()
        s[0] = 99                                       // mutate the original
        let dup0 = dup[0], dup1 = dup[1], dupCount = dup.count
        let src0 = s[0]
        #expect(dup0 == 7)
        #expect(dup1 == 8)
        #expect(dupCount == Index<Int>.Count(2))
        #expect(src0 == 99)                             // deep copy: original mutation does not leak
    }
}
