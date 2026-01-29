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

import Testing
import Storage_Primitives
import Storage_Primitives_Test_Support

@Suite("Storage.Header Tests")
struct StorageHeaderTests {

    // MARK: - Count Header Tests

    @Suite("Storage.Header.Count")
    struct CountHeaderTests {

        @Test("default initialization is zero")
        func defaultInit() throws {
            let header = Storage<Int>.Header.Count()
            #expect(header.count == .zero)
            let empty = header.isEmpty
            #expect(empty == true)
        }

        @Test("initialization with count")
        func initWithCount() throws {
            let count: Index<Int>.Count = 5
            let header = Storage<Int>.Header.Count(count: count)
            #expect(header.count == 5)
            let empty = header.isEmpty
            #expect(empty == false)
        }

        @Test("count can be modified")
        func modifyCount() throws {
            var header = Storage<Int>.Header.Count()
            let newCount: Index<Int>.Count = 10
            header.count = newCount
            #expect(header.count == 10)
        }
    }

    // MARK: - Ring Header Tests

    @Suite("Storage.Ring.Header")
    struct RingHeaderTests {

        @Test("default initialization")
        func defaultInit() throws {
            let header = Storage<Int>.Ring.Header()
            #expect(header.head == .zero)
            #expect(header.tail == .zero)
            #expect(header.count == .zero)
            let empty = header.isEmpty
            #expect(empty == true)
        }

        @Test("initialization with values")
        func initWithValues() throws {
            let head: Index<Int> = 3
            let tail: Index<Int> = 1
            let count: Index<Int>.Count = 3
            let header = Storage<Int>.Ring.Header(
                head: head,
                tail: tail,
                count: count
            )
            #expect(header.head.position == 3)
            #expect(header.tail.position == 1)
            #expect(header.count == 3)
        }

        @Test("advanceHead after dequeue")
        func advanceHead() throws {
            let head: Index<Int> = 2
            let tail: Index<Int> = 0
            let count: Index<Int>.Count = 3
            var header = Storage<Int>.Ring.Header(
                head: head,
                tail: tail,
                count: count
            )
            let capacity: Index<Int>.Count = 5

            header.advanceHead(capacity: capacity)

            #expect(header.head.position == 3)
            #expect(header.count == 2)
        }

        @Test("advanceHead wraps at capacity")
        func advanceHeadWraps() throws {
            let head: Index<Int> = 4
            let tail: Index<Int> = 2
            let count: Index<Int>.Count = 3
            var header = Storage<Int>.Ring.Header(
                head: head,
                tail: tail,
                count: count
            )
            let capacity: Index<Int>.Count = 5

            header.advanceHead(capacity: capacity)

            #expect(header.head.position == 0)
            #expect(header.count == 2)
        }

        @Test("advanceTail after enqueue")
        func advanceTail() throws {
            let head: Index<Int> = 0
            let tail: Index<Int> = 2
            let count: Index<Int>.Count = 2
            var header = Storage<Int>.Ring.Header(
                head: head,
                tail: tail,
                count: count
            )
            let capacity: Index<Int>.Count = 5

            header.advanceTail(capacity: capacity)

            #expect(header.tail.position == 3)
            #expect(header.count == 3)
        }

        @Test("advanceTail wraps at capacity")
        func advanceTailWraps() throws {
            let head: Index<Int> = 3
            let tail: Index<Int> = 4
            let count: Index<Int>.Count = 1
            var header = Storage<Int>.Ring.Header(
                head: head,
                tail: tail,
                count: count
            )
            let capacity: Index<Int>.Count = 5

            header.advanceTail(capacity: capacity)

            #expect(header.tail.position == 0)
            #expect(header.count == 2)
        }

        @Test("retreatHead for prepend")
        func retreatHead() throws {
            let head: Index<Int> = 2
            let tail: Index<Int> = 3
            let count: Index<Int>.Count = 1
            var header = Storage<Int>.Ring.Header(
                head: head,
                tail: tail,
                count: count
            )
            let capacity: Index<Int>.Count = 5

            header.retreatHead(capacity: capacity)

            #expect(header.head.position == 1)
            #expect(header.count == 2)
        }

        @Test("retreatHead wraps at zero")
        func retreatHeadWraps() throws {
            let tail: Index<Int> = 1
            let count: Index<Int>.Count = 1
            var header = Storage<Int>.Ring.Header(
                head: .zero,
                tail: tail,
                count: count
            )
            let capacity: Index<Int>.Count = 5

            header.retreatHead(capacity: capacity)

            #expect(header.head.position == 4)
            #expect(header.count == 2)
        }

        @Test("retreatTail for pop-back")
        func retreatTail() throws {
            let head: Index<Int> = 0
            let tail: Index<Int> = 3
            let count: Index<Int>.Count = 3
            var header = Storage<Int>.Ring.Header(
                head: head,
                tail: tail,
                count: count
            )
            let capacity: Index<Int>.Count = 5

            header.retreatTail(capacity: capacity)

            #expect(header.tail.position == 2)
            #expect(header.count == 2)
        }
    }

    // MARK: - Arena Header Tests

    @Suite("Storage.Header.Arena")
    struct ArenaHeaderTests {

        @Test("default initialization")
        func defaultInit() throws {
            let header = Storage<Int>.Header.Arena()
            #expect(header.head == Storage<Int>.Header.Arena.sentinel)
            #expect(header.tail == Storage<Int>.Header.Arena.sentinel)
            #expect(header.freeHead == Storage<Int>.Header.Arena.sentinel)
            #expect(header.count == .zero)
            #expect(header.capacity == .zero)
            let empty = header.isEmpty
            #expect(empty == true)
            let hasFree = header.hasFreeSlots
            #expect(hasFree == false)
        }

        @Test("initialization with capacity")
        func initWithCapacity() throws {
            let capacity: Index<Int>.Count = 16
            let header = Storage<Int>.Header.Arena(capacity: capacity)
            #expect(header.capacity.rawValue == 16)
            #expect(header.count == .zero)
            let empty = header.isEmpty
            #expect(empty == true)
        }

        @Test("sentinel is UInt.max")
        func sentinelValue() throws {
            let sentinel = Storage<Int>.Header.Arena.sentinel
            #expect(sentinel.position == Ordinal(UInt.max))
        }

        @Test("isSentinel check")
        func isSentinelCheck() throws {
            let sentinel = Storage<Int>.Header.Arena.sentinel
            let normal: Index<Int> = 5

            let isSent = Storage<Int>.Header.Arena.isSentinel(sentinel)
            #expect(isSent == true)
            let isNormalSent = Storage<Int>.Header.Arena.isSentinel(normal)
            #expect(isNormalSent == false)
        }

        @Test("hasFreeSlots when freeHead is not sentinel")
        func hasFreeSlots() throws {
            var header = Storage<Int>.Header.Arena()
            let hasFree1 = header.hasFreeSlots
            #expect(hasFree1 == false)

            let freeIndex: Index<Int> = 0
            header.freeHead = freeIndex
            let hasFree2 = header.hasFreeSlots
            #expect(hasFree2 == true)
        }
    }
}
