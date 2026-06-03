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

import Storage_Flat_Primitives
import Storage_Heap_Primitives
import Storage_Primitives_Test_Support
import Testing

@Suite("Storage.Flat Tests")
struct StorageFlatTests {

    // MARK: - Construction

    @Test
    func `lifts a heap substrate and forwards capacity`() throws {
        let capacity: Index<Int>.Count = 4
        let flat = Storage<Int>.Flat(Storage<Int>.Heap.create(minimumCapacity: capacity))
        #expect(flat.capacity >= Index<Int>.Count(4))
    }

    // MARK: - Element-store ops (Storage.Protocol witnesses)

    @Test
    func `initialize, read, mutate, move round-trips through the substrate`() throws {
        var flat = Storage<Int>.Flat(Storage<Int>.Heap.create(minimumCapacity: 4))

        flat.initialize(at: 0, to: 7)
        #expect(flat[0] == 7)

        flat[0] = 9
        #expect(flat[0] == 9)

        let moved = flat.move(at: 0)
        #expect(moved == 9)
    }

    // MARK: - Generic seam (the tower usage)

    @Test
    func `participates as a generic Storage.Protocol conformer`() throws {
        var flat = Storage<Int>.Flat(Storage<Int>.Heap.create(minimumCapacity: 4))
        Self.fill(&flat, count: 3, value: 5)
        #expect(Self.sum(flat, count: 3) == 15)
        #expect(flat.move(at: 0) == 5)
        #expect(flat.move(at: 1) == 5)
        #expect(flat.move(at: 2) == 5)
    }

    private static func fill<S: Storage.`Protocol` & ~Copyable>(
        _ storage: inout S,
        count: Int,
        value: Int
    ) where S.Element == Int {
        var i = 0
        while i < count {
            storage.initialize(at: Index<Int>(Ordinal(UInt(i))), to: value)
            i += 1
        }
    }

    private static func sum<S: Storage.`Protocol` & ~Copyable>(
        _ storage: borrowing S,
        count: Int
    ) -> Int where S.Element == Int {
        var total = 0
        var i = 0
        while i < count {
            total += storage[Index<Int>(Ordinal(UInt(i)))]
            i += 1
        }
        return total
    }

    // MARK: - Span (conditional, substrate-provided)

    @Test
    func `vends the substrate's span when the substrate is span-capable`() throws {
        // Heap's `span` covers the TRACKED initialized prefix — populate via the
        // tracked API before lifting, then read through the forwarded span.
        var heap = Storage<Int>.Heap.create(minimumCapacity: 4)
        _ = try heap.initialize.next(to: 11)
        let flat = Storage<Int>.Flat(heap)
        #expect(flat.span.count == 1)
        #expect(flat.span[0] == 11)
    }
}
