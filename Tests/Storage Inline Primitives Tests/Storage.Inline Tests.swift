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
import Synchronization
import Storage_Primitives_Core
import Storage_Inline_Primitives
import Storage_Heap_Primitives
import Storage_Primitives_Test_Support

@Suite("Storage.Inline Tests")
struct StorageInlineTests {

    // MARK: - Creation Tests

    @Test
    func `inline storage can be created`() {
        let storage = Storage<Int>.Inline<8>()
        #expect(storage.isEmpty == true)
        #expect(storage.initialization.count == 0)
    }

    // MARK: - Initialize and Move Tests

    @Test
    func `initialize and move element`() {
        var storage = Storage<Int>.Inline<8>()

        storage.initialize(to: 42, at: 0)
        #expect(storage.initialization.count == 1)

        let value = storage.move(at: 0)
        #expect(value == 42)
        #expect(storage.isEmpty == true)
    }

    @Test
    func `initialize multiple elements`() {
        var storage = Storage<Int>.Inline<8>()

        for i in 0..<8 {
            storage.initialize(to: i * 10, at: .init(integerLiteral: UInt(i)))
        }

        #expect(storage.initialization.count == 8)

        // Move in forward order to verify all initialized
        for i in 0..<8 {
            let value = storage.move(at: .init(integerLiteral: UInt(i)))
            #expect(value == i * 10)
        }

        #expect(storage.isEmpty == true)
    }

    // MARK: - Pointer Tests

    @Test
    func `pointer returns correct address`() {
        var storage = Storage<Int>.Inline<8>()

        storage.initialize(to: 99, at: 3)

        let ptr: UnsafePointer<Int> = unsafe storage.pointer(at: 3)
        let pointee = unsafe ptr.pointee
        #expect(pointee == 99)

        _ = storage.move(at: 3)
    }

    @Test
    func `mutable pointer allows modification`() {
        var storage = Storage<Int>.Inline<8>()

        storage.initialize(to: 50, at: 0)

        let ptr: UnsafeMutablePointer<Int> = unsafe storage.pointer(at: 0)
        unsafe ptr.pointee = 100

        let value = storage.move(at: 0)
        #expect(value == 100)
    }

    // MARK: - Deinitialize Tests

    @Test
    func `deinitialize at single slot`() {
        var storage = Storage<Int>.Inline<8>()

        storage.initialize(to: 42, at: 0)
        #expect(storage.initialization.count == 1)

        storage.deinitialize(at: 0)
        #expect(storage.isEmpty == true)
    }

    @Test
    func `deinitialize range of elements`() {
        var storage = Storage<Int>.Inline<8>()

        for i in 0..<4 {
            storage.initialize(to: i, at: .init(integerLiteral: UInt(i)))
        }

        #expect(storage.initialization.count == 4)

        let range: Swift.Range<Index<Int>> = .zero..<4
        storage.deinitialize(range: range)

        #expect(storage.isEmpty == true)
    }

    @Test
    func `deinit automatically cleans up tracked elements`() {
        final class Tracker: @unchecked Sendable {
            nonisolated(unsafe) static var deinitCount = 0
            deinit { unsafe Tracker.deinitCount += 1 }
        }

        unsafe Tracker.deinitCount = 0

        do {
            var storage = Storage<Tracker>.Inline<8>()

            for i in 0..<4 {
                storage.initialize(to: Tracker(), at: .init(integerLiteral: UInt(i)))
            }

            #expect(storage.initialization.count == 4)
            // storage goes out of scope - deinit should clean up
        }

        unsafe #expect(Tracker.deinitCount == 4)
    }

    @Test
    func `deinitialize partial range`() {
        final class Tracker: @unchecked Sendable {
            nonisolated(unsafe) static var deinitCount = 0
            deinit { unsafe Tracker.deinitCount += 1 }
        }

        unsafe Tracker.deinitCount = 0

        var storage = Storage<Tracker>.Inline<8>()

        for i in 0..<5 {
            storage.initialize(to: Tracker(), at: .init(integerLiteral: UInt(i)))
        }

        #expect(storage.initialization.count == 5)

        // Deinitialize slots 1..<4
        let range: Swift.Range<Index<Tracker>> = 1..<4
        storage.deinitialize(range: range)

        unsafe #expect(Tracker.deinitCount == 3)
        #expect(storage.initialization.count == 2)

        // Clean up remaining elements (slots 0 and 4)
        _ = storage.move(at: 0)
        _ = storage.move(at: 4)

        #expect(storage.isEmpty == true)
    }

    // MARK: - Type Safety Tests

    @Test
    func `different element types have separate storage`() {
        var intStorage = Storage<Int>.Inline<4>()
        var doubleStorage = Storage<Double>.Inline<4>()

        intStorage.initialize(to: 42, at: 0)
        doubleStorage.initialize(to: 3.14, at: 0)

        let intValue = intStorage.move(at: 0)
        let doubleValue = doubleStorage.move(at: 0)

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

        var storage = Storage<LargeElement>.Inline<2>()

        storage.initialize(to: LargeElement(a: 1, b: 2, c: 3), at: 0)
        storage.initialize(to: LargeElement(a: 4, b: 5, c: 6), at: 1)

        let first = storage.move(at: 0)
        let second = storage.move(at: 1)

        #expect(first.a == 1 && first.b == 2 && first.c == 3)
        #expect(second.a == 4 && second.b == 5 && second.c == 6)
    }

    // MARK: - Move to Heap Storage Tests

    @Test
    func `move range to heap storage`() {
        var inline = Storage<Int>.Inline<8>()
        let capacity: Index<Int>.Count = 8
        let heap = Storage<Int>.Heap.create(minimumCapacity: capacity)

        for i in 0..<4 {
            inline.initialize(to: (i + 1) * 100, at: .init(integerLiteral: UInt(i)))
        }

        #expect(inline.initialization.count == 4)

        let range = Swift.Range<Index<Int>>(start: .zero, count: 4)
        inline.move(range: range, to: heap)
        heap.initialization = .linear(count: 4)

        // Inline slots should be cleared after move
        #expect(inline.isEmpty == true)

        // Verify heap has the values
        var heapSlot: Index<Int> = .zero
        for i in 0..<4 {
            let value = heap.move(at: heapSlot)
            #expect(value == (i + 1) * 100)
            heapSlot = heapSlot.successor.saturating()
        }
        heap.initialization = .empty
    }

    @Test
    func `move empty range to heap storage`() {
        var inline = Storage<Int>.Inline<8>()
        let capacity: Index<Int>.Count = 8
        let heap = Storage<Int>.Heap.create(minimumCapacity: capacity)

        let range: Swift.Range<Index<Int>> = Index<Int>.zero..<Index<Int>.zero
        inline.move(range: range, to: heap)
    }

    // MARK: - Copy to Heap Storage Tests

    @Test
    func `copy range to heap storage`() {
        var inline = Storage<Int>.Inline<8>()
        let capacity: Index<Int>.Count = 8
        let heap = Storage<Int>.Heap.create(minimumCapacity: capacity)

        for i in 0..<4 {
            inline.initialize(to: i * 5, at: .init(integerLiteral: UInt(i)))
        }

        let range: Swift.Range<Index<Int>> = .zero..<4
        inline.copy(range: range, to: heap)
        heap.initialization = .linear(count: 4)

        // Inline slots should still be initialized after copy
        #expect(inline.initialization.count == 4)

        // Verify inline still has original values
        for i in 0..<4 {
            let value = inline.move(at: .init(integerLiteral: UInt(i)))
            #expect(value == i * 5)
        }

        // Verify heap has copies
        var heapSlot: Index<Int> = .zero
        for i in 0..<4 {
            let value = heap.move(at: heapSlot)
            #expect(value == i * 5)
            heapSlot = heapSlot.successor.saturating()
        }
        heap.initialization = .empty
    }

    @Test
    func `copy empty range to heap storage`() {
        let inline = Storage<Int>.Inline<8>()
        let capacity: Index<Int>.Count = 8
        let heap = Storage<Int>.Heap.create(minimumCapacity: capacity)

        let range: Swift.Range<Index<Int>> = Index<Int>.zero..<Index<Int>.zero
        inline.copy(range: range, to: heap)
    }

    // MARK: - ~Copyable Deinitialize Tests

    @Test
    func `deinitialize range with noncopyable elements via pointer init`() {
        // Reproduces Vector.Inline pattern: init via pointer, deinit via range
        final class DeinitTracker: @unchecked Sendable {
            let _count = Atomic<Int>(0)
            var count: Int { _count.load(ordering: .relaxed) }
            func increment() { _count.wrappingAdd(1, ordering: .relaxed) }
        }

        struct TrackedValue: ~Copyable {
            let value: Int
            let tracker: DeinitTracker
            init(_ value: Int, tracker: DeinitTracker) {
                self.value = value
                self.tracker = tracker
            }
            deinit { tracker.increment() }
        }

        let tracker = DeinitTracker()

        do {
            var storage = Storage<TrackedValue>.Inline<3>()

            // Initialize via pointer (like Vector.Inline.init(initializing:))
            // Note: pointer-based init bypasses auto-tracking
            let ptr: UnsafeMutablePointer<TrackedValue> = unsafe storage.pointer(at: 0)
            unsafe (ptr + 0).initialize(to: TrackedValue(1, tracker: tracker))
            unsafe (ptr + 1).initialize(to: TrackedValue(2, tracker: tracker))
            unsafe (ptr + 2).initialize(to: TrackedValue(3, tracker: tracker))

            #expect(tracker.count == 0) // Elements should be alive

            // Deinitialize via range (like Vector.Inline.deinit)
            let range: Swift.Range<Index<TrackedValue>> = .zero ..< Index<TrackedValue>(Ordinal(UInt(3)))
            storage.deinitialize(range: range)

            #expect(tracker.count == 3) // All elements should be deinitialized
        }
    }

    @Test
    func `storage inline deinit is called`() {
        final class DeinitFlag: @unchecked Sendable {
            var called = false
        }

        let flag = DeinitFlag()

        struct Wrapper: ~Copyable {
            let flag: DeinitFlag
            var storage: Storage<Int>.Inline<3>
            deinit {
                flag.called = true
            }
        }

        do {
            let w = Wrapper(flag: flag, storage: Storage<Int>.Inline<3>())
            _ = w
        }

        #expect(flag.called == true)
    }

    @Test
    func `rawlayout struct deinit runs`() {
        // Test if a struct with @_rawLayout field gets deinit called
        final class Flag: @unchecked Sendable {
            var called = false
        }

        @_rawLayout(likeArrayOf: Int, count: 3)
        struct RawStorage: ~Copyable {}

        struct TestStruct: ~Copyable {
            var _raw: RawStorage
            let flag: Flag

            init(flag: Flag) {
                self._raw = RawStorage()
                self.flag = flag
            }

            deinit {
                flag.called = true
            }
        }

        let flag = Flag()

        do {
            let t = TestStruct(flag: flag)
            _ = t
        }

        #expect(flag.called == true)
    }

    @Test
    func `Storage_Inline deinit cleans up via bitvector tracking`() {
        // Use a class element to track if Storage.Inline's deinit actually deinitializes
        final class Marker: @unchecked Sendable {
            nonisolated(unsafe) static var instanceCount = 0
            init() { unsafe Marker.instanceCount += 1 }
            deinit { unsafe Marker.instanceCount -= 1 }
        }

        unsafe Marker.instanceCount = 0

        do {
            var storage = Storage<Marker>.Inline<2>()
            storage.initialize(to: Marker(), at: 0)
            storage.initialize(to: Marker(), at: 1)

            #expect(storage.initialization.count == 2)
            unsafe #expect(Marker.instanceCount == 2)
            // storage goes out of scope, Storage.Inline.deinit should run
        }

        // If Storage.Inline.deinit ran and called _deinitializeTrackedSlots(), markers should be gone
        unsafe #expect(Marker.instanceCount == 0)
    }

    // MARK: - Sparse Initialization Tests (new capability with BitVector)

    @Test
    func `sparse initialization pattern`() {
        // BitVector supports any initialization pattern, not just contiguous ranges
        final class Tracker: @unchecked Sendable {
            nonisolated(unsafe) static var deinitCount = 0
            deinit { unsafe Tracker.deinitCount += 1 }
        }

        unsafe Tracker.deinitCount = 0

        do {
            var storage = Storage<Tracker>.Inline<8>()

            // Initialize sparse slots: 0, 3, 7
            storage.initialize(to: Tracker(), at: 0)
            storage.initialize(to: Tracker(), at: 3)
            storage.initialize(to: Tracker(), at: 7)

            #expect(storage.initialization.count == 3)
            // deinit will clean up exactly these 3 slots
        }

        unsafe #expect(Tracker.deinitCount == 3)
    }

    @Test
    func `disjoint ranges cleanup`() {
        // Simulates wrapped ring buffer pattern
        final class Tracker: @unchecked Sendable {
            nonisolated(unsafe) static var deinitCount = 0
            deinit { unsafe Tracker.deinitCount += 1 }
        }

        unsafe Tracker.deinitCount = 0

        do {
            var storage = Storage<Tracker>.Inline<8>()

            // Initialize slots 0, 1, 2 and slots 6, 7 (simulating wrapped ring buffer)
            storage.initialize(to: Tracker(), at: 0)
            storage.initialize(to: Tracker(), at: 1)
            storage.initialize(to: Tracker(), at: 2)
            storage.initialize(to: Tracker(), at: 6)
            storage.initialize(to: Tracker(), at: 7)

            #expect(storage.initialization.count == 5)
            // deinit will clean up all 5 slots
        }

        unsafe #expect(Tracker.deinitCount == 5)
    }
}
