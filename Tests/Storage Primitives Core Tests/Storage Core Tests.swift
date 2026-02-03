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
    func `Storage Slot types exist`() throws {
        let _: Storage.Slot.Type = Storage.Slot.self
        let _: Storage.Slot.Count.Type = Storage.Slot.Count.self
        let _: Storage.Slot.Offset.Type = Storage.Slot.Offset.self
    }

    @Test
    func `Storage Span type exists`() throws {
        let _: Storage.Span.Type = Storage.Span.self
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
        let span = Storage.Span.empty
        #expect(span.isEmpty)
        #expect(span.lowerBound == .zero)
        #expect(span.upperBound == .zero)
    }

    @Test
    func `span from start and count`() throws {
        let span = Storage.Span(start: .zero, count: Storage.Slot.Count(5))
        #expect(!span.isEmpty)
        #expect(span.count == Storage.Slot.Count(5))
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
        let init_ = Storage.Initialization.linear(count: Storage.Slot.Count(5))
        #expect(!init_.isEmpty)
        #expect(init_.count == Storage.Slot.Count(5))
    }

    @Test
    func `initialization linear zero is empty`() throws {
        let init_ = Storage.Initialization.linear(count: .zero)
        #expect(init_.isEmpty)
    }

    @Test
    func `initialization two spans`() throws {
        let first = Storage.Span(start: .zero, count: Storage.Slot.Count(3))
        let second = Storage.Span(start: Storage.Slot(6), count: Storage.Slot.Count(2))
        let init_ = Storage.Initialization.two(first: first, second: second)
        #expect(!init_.isEmpty)
        #expect(init_.count == Storage.Slot.Count(5))
    }
}
