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
import Storage_Primitives_Core
import Storage_Primitives_Test_Support

@Suite("Storage Core Tests")
struct StorageCoreTests {

    // MARK: - Type Existence Tests

    @Test
    func `Storage namespace exists`() throws {
        let _: Storage.Type = Storage.self
    }

    @Test
    func `Storage Heap type exists`() throws {
        let _: Storage.Heap<Int>.Type = Storage.Heap<Int>.self
    }

    @Test
    func `Storage Inline type exists`() throws {
        let _: Storage.Inline<Int, 8>.Type = Storage.Inline<Int, 8>.self
    }

    @Test
    func `Index Storage types exist`() throws {
        let _: Index<Storage>.Type = Index<Storage>.self
        let _: Index<Storage>.Count.Type = Index<Storage>.Count.self
        let _: Index<Storage>.Offset.Type = Index<Storage>.Offset.self
    }

    @Test
    func `Storage Span type exists`() throws {
        let _: Swift.Range<Index<Storage>>.Type = Swift.Range<Index<Storage>>.self
    }

    @Test
    func `Storage Initialization type exists`() throws {
        let _: Storage.Initialization.Type = Storage.Initialization.self
    }

    @Test
    func `Storage Header type exists`() throws {
        let _: Storage.Heap.Header.Type = Storage.Heap<Int>.Header.self
    }

    // MARK: - Span Tests

    @Test
    func `span empty factory`() throws {
        let span = Swift.Range<Index<Storage>>.empty
        #expect(span.isEmpty)
        #expect(span.lowerBound == .zero)
        #expect(span.upperBound == .zero)
    }

    @Test
    func `span from start and count`() throws {
        let span = Swift.Range<Index<Storage>>(start: .zero, count: Index<Storage>.Count(5))
        #expect(!span.isEmpty)
        #expect(span.count == Index<Storage>.Count(5))
    }

    // MARK: - Initialization Tests

    @Test
    func `initialization empty`() throws {
        let init_ = Storage.Initialization.empty
        #expect(init_.isEmpty)
        #expect(init_.count == .zero)
    }

    @Test
    func `initialization linear`() throws {
        let init_ = Storage.Initialization.linear(count: Index<Storage>.Count(5))
        #expect(!init_.isEmpty)
        #expect(init_.count == Index<Storage>.Count(5))
    }

    @Test
    func `initialization linear zero is empty`() throws {
        let init_ = Storage.Initialization.linear(count: .zero)
        #expect(init_.isEmpty)
    }

    @Test
    func `initialization two spans`() throws {
        let first = Swift.Range<Index<Storage>>(start: .zero, count: Index<Storage>.Count(3))
        let second = Swift.Range<Index<Storage>>(start: Index<Storage>(6), count: Index<Storage>.Count(2))
        let init_ = Storage.Initialization.two(first: first, second: second)
        #expect(!init_.isEmpty)
        #expect(init_.count == Index<Storage>.Count(5))
    }
}
