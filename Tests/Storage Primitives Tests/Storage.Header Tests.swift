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
    // MARK: - Arena Header Tests
    //
    // Note: Ring header tests moved to buffer-primitives with Buffer.Ring.Header

    @Suite("Storage.Header.Arena")
    struct ArenaHeaderTests {

        @Test
        func `default initialization`() throws {
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

        @Test
        func `initialization with capacity`() throws {
            let capacity: Index<Int>.Count = 16
            let header = Storage<Int>.Header.Arena(capacity: capacity)
            #expect(header.capacity == 16)
            #expect(header.count == .zero)
            let empty = header.isEmpty
            #expect(empty == true)
        }

        @Test
        func `sentinel is UInt max`() throws {
            let sentinel = Storage<Int>.Header.Arena.sentinel
            #expect(sentinel.position == Ordinal(UInt.max))
        }

        @Test
        func `isSentinel check`() throws {
            let sentinel = Storage<Int>.Header.Arena.sentinel
            let normal: Index<Int> = 5

            let isSent = Storage<Int>.Header.Arena.isSentinel(sentinel)
            #expect(isSent == true)
            let isNormalSent = Storage<Int>.Header.Arena.isSentinel(normal)
            #expect(isNormalSent == false)
        }

        @Test
        func `hasFreeSlots when freeHead is not sentinel`() throws {
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
