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
import Storage_Inline_Primitives
import Storage_Heap_Primitives
import Storage_Primitives_Test_Support

@Suite("Storage.Inline Tests")
struct StorageInlineTests {

    // MARK: - Creation Tests

    @Test
    func `inline storage can be created`() {
        let storage = Storage.Inline<Int, 8>()
        _ = storage
    }

    // MARK: - Initialize and Move Tests

    @Test
    func `initialize and move element`() {
        var storage = Storage.Inline<Int, 8>()
        let slot: Index<Storage> = .zero

        storage.initialize(to: 42, at: slot)
        let value = storage.move(at: slot)

        #expect(value == 42)
    }

    @Test
    func `initialize multiple elements`() {
        var storage = Storage.Inline<Int, 8>()

        var slot: Index<Storage> = .zero
        for i in 0..<8 {
            storage.initialize(to: i * 10, at: slot)
            slot = slot.successor.saturating()
        }

        // Move in forward order to verify all initialized
        slot = .zero
        for i in 0..<8 {
            let value = storage.move(at: slot)
            #expect(value == i * 10)
            slot = slot.successor.saturating()
        }
    }

    // MARK: - Pointer Tests

    @Test
    func `pointer returns correct address`() {
        var storage = Storage.Inline<Int, 8>()
        let slot = Index<Storage>(3)

        storage.initialize(to: 99, at: slot)

        let ptr: UnsafeMutablePointer<Int> = unsafe storage.pointer(at: slot)
        let pointee = unsafe ptr.pointee
        #expect(pointee == 99)

        _ = storage.move(at: slot)
    }

    @Test
    func `mutable pointer allows modification`() {
        var storage = Storage.Inline<Int, 8>()
        let slot: Index<Storage> = .zero

        storage.initialize(to: 50, at: slot)

        let ptr: UnsafeMutablePointer<Int> = unsafe storage.pointer(at: slot)
        unsafe ptr.pointee = 100

        let value = storage.move(at: slot)
        #expect(value == 100)
    }

    // MARK: - Deinitialize Tests

    @Test
    func `deinitialize at single slot`() {
        var storage = Storage.Inline<Int, 8>()

        storage.initialize(to: 42, at: .zero)
        storage.deinitialize(at: .zero)
    }

    @Test
    func `deinitialize range of elements`() {
        var storage = Storage.Inline<Int, 8>()

        var slot: Index<Storage> = .zero
        for i in 0..<4 {
            storage.initialize(to: i, at: slot)
            slot = slot.successor.saturating()
        }

        let range: Swift.Range<Index<Storage>> = .zero..<4
        storage.deinitialize(range: range)
    }

    @Test
    func `deinitialize all tracked elements`() {
        final class Tracker: @unchecked Sendable {
            nonisolated(unsafe) static var deinitCount = 0
            deinit { unsafe Tracker.deinitCount += 1 }
        }

        unsafe Tracker.deinitCount = 0

        var storage = Storage.Inline<Tracker, 8>()

        var slot: Index<Storage> = .zero
        for _ in 0..<4 {
            storage.initialize(to: Tracker(), at: slot)
            slot = slot.successor.saturating()
        }
        storage.initialization = .linear(count: 4)

        storage.deinitialize()
        #expect(storage.initialization.isEmpty)

        unsafe #expect(Tracker.deinitCount == 4)
    }

    @Test
    func `deinitialize partial range`() {
        final class Tracker: @unchecked Sendable {
            nonisolated(unsafe) static var deinitCount = 0
            deinit { unsafe Tracker.deinitCount += 1 }
        }

        unsafe Tracker.deinitCount = 0

        var storage = Storage.Inline<Tracker, 8>()

        var slot: Index<Storage> = .zero
        for _ in 0..<5 {
            storage.initialize(to: Tracker(), at: slot)
            slot = slot.successor.saturating()
        }

        // Deinitialize slots 1..<4
        let range: Swift.Range<Index<Storage>> = 1..<4
        storage.deinitialize(range: range)

        unsafe #expect(Tracker.deinitCount == 3)

        // Clean up remaining elements (slots 0 and 4)
        _ = storage.move(at: 0)
        _ = storage.move(at: 4)
    }

    // MARK: - Type Safety Tests

    @Test
    func `different element types have separate storage`() {
        var intStorage = Storage.Inline<Int, 4>()
        var doubleStorage = Storage.Inline<Double, 4>()

        intStorage.initialize(to: 42, at: .zero)
        doubleStorage.initialize(to: 3.14, at: .zero)

        let intValue = intStorage.move(at: .zero)
        let doubleValue = doubleStorage.move(at: .zero)

        #expect(intValue == 42)
        #expect(doubleValue == 3.14)
    }

    // MARK: - Stride-Based Access Tests

    @Test
    func `stride-based access works for different element sizes`() {
        struct LargeElement {
            var a: Int
            var b: Int
            var c: Int
        }

        var storage = Storage.Inline<LargeElement, 2>()
        let slot1: Index<Storage> = 1

        storage.initialize(to: LargeElement(a: 1, b: 2, c: 3), at: .zero)
        storage.initialize(to: LargeElement(a: 4, b: 5, c: 6), at: slot1)

        let first = storage.move(at: .zero)
        let second = storage.move(at: slot1)

        #expect(first.a == 1 && first.b == 2 && first.c == 3)
        #expect(second.a == 4 && second.b == 5 && second.c == 6)
    }

    // MARK: - Move to Heap Storage Tests

    @Test
    func `move range to heap storage`() {
        var inline = Storage.Inline<Int, 8>()
        let capacity: Index<Storage>.Count = 8
        let heap = Storage.Heap<Int>.create(minimumCapacity: capacity)

        var slot: Index<Storage> = .zero
        for i in 0..<4 {
            inline.initialize(to: (i + 1) * 100, at: slot)
            slot = slot.successor.saturating()
        }

        let range = Swift.Range<Index<Storage>>(start: .zero, count: 4)
        inline.move(range: range, to: heap)
        heap.initialization = .linear(count: 4)

        // Verify heap has the values
        slot = .zero
        for i in 0..<4 {
            let value = heap.move(at: slot)
            #expect(value == (i + 1) * 100)
            slot = slot.successor.saturating()
        }
        heap.initialization = .empty
    }

    @Test
    func `move empty range to heap storage`() {
        var inline = Storage.Inline<Int, 8>()
        let capacity: Index<Storage>.Count = 8
        let heap = Storage.Heap<Int>.create(minimumCapacity: capacity)

        let range = Swift.Range<Index<Storage>>.empty
        inline.move(range: range, to: heap)
    }

    // MARK: - Copy to Heap Storage Tests

    @Test
    func `copy range to heap storage`() {
        var inline = Storage.Inline<Int, 8>()
        let capacity: Index<Storage>.Count = 8
        let heap = Storage.Heap<Int>.create(minimumCapacity: capacity)

        var slot: Index<Storage> = .zero
        for i in 0..<4 {
            inline.initialize(to: i * 5, at: slot)
            slot = slot.successor.saturating()
        }

        let range: Swift.Range<Index<Storage>> = .zero..<4
        inline.copy(range: range, to: heap)
        heap.initialization = .linear(count: 4)

        // Verify inline still has original values
        slot = .zero
        for i in 0..<4 {
            let value = inline.move(at: slot)
            #expect(value == i * 5)
            slot = slot.successor.saturating()
        }

        // Verify heap has copies
        slot = .zero
        for i in 0..<4 {
            let value = heap.move(at: slot)
            #expect(value == i * 5)
            slot = slot.successor.saturating()
        }
        heap.initialization = .empty
    }

    @Test
    func `copy empty range to heap storage`() {
        let inline = Storage.Inline<Int, 8>()
        let capacity: Index<Storage>.Count = 8
        let heap = Storage.Heap<Int>.create(minimumCapacity: capacity)

        let range = Swift.Range<Index<Storage>>.empty
        inline.copy(range: range, to: heap)
    }

    // MARK: - Two-Span Deinitialize Tests

    @Test
    func `deinitialize with two-range initialization`() {
        final class Tracker: @unchecked Sendable {
            nonisolated(unsafe) static var deinitCount = 0
            deinit { unsafe Tracker.deinitCount += 1 }
        }

        unsafe Tracker.deinitCount = 0

        var storage = Storage.Inline<Tracker, 8>()

        // Initialize slots 0, 1, 2 and slots 6, 7 (simulating wrapped ring buffer)
        storage.initialize(to: Tracker(), at: 0)
        storage.initialize(to: Tracker(), at: 1)
        storage.initialize(to: Tracker(), at: 2)
        storage.initialize(to: Tracker(), at: 6)
        storage.initialize(to: Tracker(), at: 7)

        let first: Swift.Range<Index<Storage>> = .init(start: .zero, count: 3)
        let second: Swift.Range<Index<Storage>> = .init(start: 6, count: 2)
        storage.initialization = .two(first: first, second: second)

        storage.deinitialize()

        unsafe #expect(Tracker.deinitCount == 5)
        #expect(storage.initialization.isEmpty)
    }
}
