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

    @Test("successor increments position")
    func successorIncrements() throws {
        let index: Index<Int> = .zero
        let next = Storage<Int>.Contiguous.successor(of: index)
        #expect(next.position.rawValue == 1)
    }

    @Test("successor via Index extension")
    func successorExtension() throws {
        let index = Index<Int>(__unchecked: (), 5)
        let next = index.successor()
        #expect(next.position.rawValue == 6)
    }

    @Test("multiple successor calls")
    func multipleSuccessors() throws {
        var index: Index<Int> = .zero
        for i in 1...10 {
            index = index.successor()
            #expect(index.position.rawValue == i)
        }
    }

    // MARK: - Predecessor Tests

    @Test("predecessor decrements position")
    func predecessorDecrements() throws {
        let index = Index<Int>(__unchecked: (), 5)
        let prev = Storage<Int>.Contiguous.predecessor(of: index)
        #expect(prev.position.rawValue == 4)
    }

    @Test("predecessor via Index extension")
    func predecessorExtension() throws {
        let index = Index<Int>(__unchecked: (), 10)
        let prev = index.predecessor()
        #expect(prev.position.rawValue == 9)
    }

    @Test("predecessor to zero")
    func predecessorToZero() throws {
        let index = Index<Int>(__unchecked: (), 1)
        let zero = index.predecessor()
        #expect(zero.position.rawValue == 0)
    }

    // MARK: - Combined Operations

    @Test("successor then predecessor returns original")
    func roundTrip() throws {
        let original = Index<Int>(__unchecked: (), 42)
        let incremented = original.successor()
        let decremented = incremented.predecessor()
        #expect(decremented == original)
    }

    @Test("predecessor then successor returns original")
    func reverseRoundTrip() throws {
        let original = Index<Int>(__unchecked: (), 42)
        let decremented = original.predecessor()
        let incremented = decremented.successor()
        #expect(incremented == original)
    }
}
