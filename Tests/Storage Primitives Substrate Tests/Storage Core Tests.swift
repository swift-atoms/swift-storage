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

import Storage_Accessor_Primitives
import Storage_Error_Primitives
import Storage_Initialization_Primitives
import Storage_Primitive
import Storage_Primitives_Test_Support
import Testing

@Suite("Storage Core Tests")
struct StorageCoreTests {

    // MARK: - Type Existence Tests

    @Test
    func `Storage namespace exists`() throws {
        let _: Storage<Int>.Type = Storage<Int>.self
    }

    @Test
    func `Storage Heap type exists`() throws {
        let _: Storage<Int>.Heap.Type = Storage<Int>.Heap.self
    }

    @Test
    func `Storage Inline type exists`() throws {
        let _: Storage<Int>.Inline<8>.Type = Storage<Int>.Inline<8>.self
    }

    @Test
    func `Index Element types exist`() throws {
        let _: Index<Int>.Type = Index<Int>.self
        let _: Index<Int>.Count.Type = Index<Int>.Count.self
        let _: Index<Int>.Offset.Type = Index<Int>.Offset.self
    }

    @Test
    func `Storage Span type exists`() throws {
        let _: Swift.Range<Index<Int>>.Type = Swift.Range<Index<Int>>.self
    }

    @Test
    func `Storage Initialization type exists`() throws {
        let _: Storage<Int>.Initialization.Type = Storage<Int>.Initialization.self
    }

    @Test
    func `Heap leaf Header type exists`() throws {
        // Post-split: the header (and its ledger) live on the Memory.Heap LEAF —
        // Storage<E>.Heap is the Contiguous<Memory.Heap<E>> typealias and the
        // discipline carries no header of its own (storage-memory-split.md §3).
        let _: Memory.Heap<Int>.Header.Type = Memory.Heap<Int>.Header.self
    }

    // MARK: - Span Tests

    @Test
    func `span empty`() throws {
        let span: Swift.Range<Index<Int>> = Index<Int>.zero..<Index<Int>.zero
        #expect(span.isEmpty)
        #expect(span.lowerBound == .zero)
        #expect(span.upperBound == .zero)
    }

    @Test
    func `span from start and count`() throws {
        let span = Swift.Range<Index<Int>>(start: .zero, count: Index<Int>.Count(5))
        #expect(!span.isEmpty)
        #expect(span.count == Index<Int>.Count(5))
    }

    // MARK: - Initialization Tests

    @Test
    func `initialization empty`() throws {
        let init_: Storage<Int>.Initialization = .empty
        #expect(init_.isEmpty)
        #expect(init_.count == .zero)
    }

    @Test
    func `initialization linear`() throws {
        let init_: Storage<Int>.Initialization = .linear(count: Index<Int>.Count(5))
        #expect(!init_.isEmpty)
        #expect(init_.count == Index<Int>.Count(5))
    }

    @Test
    func `initialization linear zero is empty`() throws {
        let init_: Storage<Int>.Initialization = .linear(count: .zero)
        #expect(init_.isEmpty)
    }

    @Test
    func `initialization two spans`() throws {
        let first = Swift.Range<Index<Int>>(start: .zero, count: Index<Int>.Count(3))
        let second = Swift.Range<Index<Int>>(start: Index<Int>(6), count: Index<Int>.Count(2))
        let init_: Storage<Int>.Initialization = .two(first: first, second: second)
        #expect(!init_.isEmpty)
        #expect(init_.count == Index<Int>.Count(5))
    }
}
