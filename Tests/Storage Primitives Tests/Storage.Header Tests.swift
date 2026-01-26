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
            let header = Storage<Int>.Header.Count(count: Index<Int>.Count(__unchecked: 5))
            #expect(header.count.rawValue == 5)
            let empty = header.isEmpty
            #expect(empty == false)
        }

        @Test("count can be modified")
        func modifyCount() throws {
            var header = Storage<Int>.Header.Count()
            header.count = Index<Int>.Count(__unchecked: 10)
            #expect(header.count.rawValue == 10)
        }
    }

    // MARK: - Ring Header Tests

    @Suite("Storage.Header.Ring")
    struct RingHeaderTests {

        @Test("default initialization")
        func defaultInit() throws {
            let header = Storage<Int>.Header.Ring()
            #expect(header.head == .zero)
            #expect(header.tail == .zero)
            #expect(header.count == .zero)
            let empty = header.isEmpty
            #expect(empty == true)
        }

        @Test("initialization with values")
        func initWithValues() throws {
            let header = Storage<Int>.Header.Ring(
                head: Index(__unchecked: (), position: 3),
                tail: Index(__unchecked: (), position: 1),
                count: Index<Int>.Count(__unchecked: 3)
            )
            #expect(header.head.position.rawValue == 3)
            #expect(header.tail.position.rawValue == 1)
            #expect(header.count.rawValue == 3)
        }

        @Test("advanceHead after dequeue")
        func advanceHead() throws {
            var header = Storage<Int>.Header.Ring(
                head: Index(__unchecked: (), position: 2),
                tail: Index(__unchecked: (), position: 0),
                count: Index<Int>.Count(__unchecked: 3)
            )
            let capacity: Index<Int>.Count = 5

            header.advanceHead(capacity: capacity)

            #expect(header.head.position.rawValue == 3)
            #expect(header.count.rawValue == 2)
        }

        @Test("advanceHead wraps at capacity")
        func advanceHeadWraps() throws {
            var header = Storage<Int>.Header.Ring(
                head: Index(__unchecked: (), position: 4),
                tail: Index(__unchecked: (), position: 2),
                count: Index<Int>.Count(__unchecked: 3)
            )
            let capacity: Index<Int>.Count = 5

            header.advanceHead(capacity: capacity)

            #expect(header.head.position.rawValue == 0)
            #expect(header.count.rawValue == 2)
        }

        @Test("advanceTail after enqueue")
        func advanceTail() throws {
            var header = Storage<Int>.Header.Ring(
                head: Index(__unchecked: (), position: 0),
                tail: Index(__unchecked: (), position: 2),
                count: Index<Int>.Count(__unchecked: 2)
            )
            let capacity: Index<Int>.Count = 5

            header.advanceTail(capacity: capacity)

            #expect(header.tail.position.rawValue == 3)
            #expect(header.count.rawValue == 3)
        }

        @Test("advanceTail wraps at capacity")
        func advanceTailWraps() throws {
            var header = Storage<Int>.Header.Ring(
                head: Index(__unchecked: (), position: 3),
                tail: Index(__unchecked: (), position: 4),
                count: Index<Int>.Count(__unchecked: 1)
            )
            let capacity: Index<Int>.Count = 5

            header.advanceTail(capacity: capacity)

            #expect(header.tail.position.rawValue == 0)
            #expect(header.count.rawValue == 2)
        }

        @Test("retreatHead for prepend")
        func retreatHead() throws {
            var header = Storage<Int>.Header.Ring(
                head: Index(__unchecked: (), position: 2),
                tail: Index(__unchecked: (), position: 3),
                count: Index<Int>.Count(__unchecked: 1)
            )
            let capacity: Index<Int>.Count = 5

            header.retreatHead(capacity: capacity)

            #expect(header.head.position.rawValue == 1)
            #expect(header.count.rawValue == 2)
        }

        @Test("retreatHead wraps at zero")
        func retreatHeadWraps() throws {
            var header = Storage<Int>.Header.Ring(
                head: .zero,
                tail: Index(__unchecked: (), position: 1),
                count: Index<Int>.Count(__unchecked: 1)
            )
            let capacity: Index<Int>.Count = 5

            header.retreatHead(capacity: capacity)

            #expect(header.head.position.rawValue == 4)
            #expect(header.count.rawValue == 2)
        }

        @Test("retreatTail for pop-back")
        func retreatTail() throws {
            var header = Storage<Int>.Header.Ring(
                head: Index(__unchecked: (), position: 0),
                tail: Index(__unchecked: (), position: 3),
                count: Index<Int>.Count(__unchecked: 3)
            )
            let capacity: Index<Int>.Count = 5

            header.retreatTail(capacity: capacity)

            #expect(header.tail.position.rawValue == 2)
            #expect(header.count.rawValue == 2)
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
            let header = Storage<Int>.Header.Arena(capacity: Index<Int>.Count(__unchecked: 16))
            #expect(header.capacity.rawValue == 16)
            #expect(header.count == .zero)
            let empty = header.isEmpty
            #expect(empty == true)
        }

        @Test("sentinel is negative")
        func sentinelValue() throws {
            let sentinel = Storage<Int>.Header.Arena.sentinel
            #expect(sentinel.position.rawValue == -1)
        }

        @Test("isSentinel check")
        func isSentinelCheck() throws {
            let sentinel = Storage<Int>.Header.Arena.sentinel
            let normal = Index<Int>(__unchecked: (), position: 5)

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

            header.freeHead = Index(__unchecked: (), position: 0)
            let hasFree2 = header.hasFreeSlots
            #expect(hasFree2 == true)
        }
    }
}
