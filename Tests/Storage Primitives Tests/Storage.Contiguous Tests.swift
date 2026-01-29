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

@Suite("Storage.Contiguous Tests")
struct StorageContiguousTests {

    // MARK: - Successor Tests

    @Test
    func `successor increments position`() throws {
        let index: Index<Int> = .zero
        let next = Storage<Int>.Contiguous.successor(of: index)
        #expect(next.position == 1)
    }

    @Test
    func `successor via Index extension`() throws {
        let index: Index<Int> = 5
        let next = index + .one
        #expect(next.position == 6)
    }

    @Test
    func `multiple successor calls`() throws {
        var index: Index<Int> = .zero
        for i: UInt in 1...10 {
            index = index + .one
            #expect(index.position == Ordinal(i))
        }
    }

    // MARK: - Predecessor Tests

    @Test
    func `predecessor decrements position`() throws {
        let index: Index<Int> = 5
        let prev = try Storage<Int>.Contiguous.predecessor(of: index)
        #expect(prev.position == 4)
    }

    @Test
    func `predecessor via Index extension`() throws {
        let index: Index<Int> = 10
        let prev = try index - .one
        #expect(prev.position == 9)
    }

    @Test
    func `predecessor to zero`() throws {
        let index: Index<Int> = 1
        let zero = try index - .one
        #expect(zero.position == 0)
    }

    // MARK: - Combined Operations

    @Test
    func `successor then predecessor returns original`() throws {
        let original: Index<Int> = 42
        let incremented = original + .one
        let decremented = try incremented - .one
        #expect(decremented == original)
    }

    @Test
    func `predecessor then successor returns original`() throws {
        let original: Index<Int> = 42
        let decremented = try original - .one
        let incremented = decremented + .one
        #expect(incremented == original)
    }
}
