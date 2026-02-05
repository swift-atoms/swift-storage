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

// MARK: - Storage.Inline Invariant Tests
// Tests organized by invariant categories from Research/storage-inline-invariants.md

@Suite("Storage.Inline Invariants")
struct StorageInlineInvariantTests {

    // =========================================================================
    // MARK: - INV-INLINE-001: Layout Invariants
    // =========================================================================

    @Suite("INV-INLINE-001: Layout")
    struct Layout {

        @Test
        func `INV-INLINE-001a: size equals stride times capacity plus bitvector overhead`() {
            // For Int with capacity 4
            let intStride = MemoryLayout<Int>.stride
            let bitvectorSize = 32 // 4 words × 8 bytes = 32 bytes for Bit.Vector.Static<4>
            let expectedIntSize = intStride * 4 + bitvectorSize
            let actualIntSize = MemoryLayout<Storage<Int>.Inline<4>>.size

            // Actual size may include alignment padding, so use >= for lower bound
            #expect(actualIntSize >= intStride * 4, "Storage must hold at least 4 Ints")
            #expect(actualIntSize <= expectedIntSize + 16, "Size should be close to expected")

            // For Double with capacity 8
            let doubleStride = MemoryLayout<Double>.stride
            let expectedDoubleSize = doubleStride * 8 + bitvectorSize
            let actualDoubleSize = MemoryLayout<Storage<Double>.Inline<8>>.size

            #expect(actualDoubleSize >= doubleStride * 8, "Storage must hold at least 8 Doubles")
            #expect(actualDoubleSize <= expectedDoubleSize + 16, "Size should be close to expected")
        }

        @Test
        func `INV-INLINE-001b: alignment is at least element alignment`() {
            // Int alignment
            let intAlignment = MemoryLayout<Int>.alignment
            let storageIntAlignment = MemoryLayout<Storage<Int>.Inline<4>>.alignment
            #expect(storageIntAlignment >= intAlignment)

            // Double alignment
            let doubleAlignment = MemoryLayout<Double>.alignment
            let storageDoubleAlignment = MemoryLayout<Storage<Double>.Inline<4>>.alignment
            #expect(storageDoubleAlignment >= doubleAlignment)

            // UInt8 alignment (1 byte)
            let uint8Alignment = MemoryLayout<UInt8>.alignment
            let storageUInt8Alignment = MemoryLayout<Storage<UInt8>.Inline<16>>.alignment
            #expect(storageUInt8Alignment >= uint8Alignment)
        }

        @Test
        func `INV-INLINE-001c: elements are contiguous at stride offsets`() {
            var storage = Storage<Int>.Inline<4>()

            // Initialize all slots
            storage.initialize(to: 100, at: 0)
            storage.initialize(to: 200, at: 1)
            storage.initialize(to: 300, at: 2)
            storage.initialize(to: 400, at: 3)

            // Get pointers and verify stride-based layout
            let ptr0: UnsafeMutablePointer<Int> = unsafe storage.pointer(at: 0)
            let ptr1: UnsafeMutablePointer<Int> = unsafe storage.pointer(at: 1)
            let ptr2: UnsafeMutablePointer<Int> = unsafe storage.pointer(at: 2)
            let ptr3: UnsafeMutablePointer<Int> = unsafe storage.pointer(at: 3)

            let stride = MemoryLayout<Int>.stride

            let diff01 = unsafe UnsafeRawPointer(ptr1) - UnsafeRawPointer(ptr0)
            let diff12 = unsafe UnsafeRawPointer(ptr2) - UnsafeRawPointer(ptr1)
            let diff23 = unsafe UnsafeRawPointer(ptr3) - UnsafeRawPointer(ptr2)

            #expect(diff01 == stride, "Slot 0 to 1 should be exactly one stride")
            #expect(diff12 == stride, "Slot 1 to 2 should be exactly one stride")
            #expect(diff23 == stride, "Slot 2 to 3 should be exactly one stride")

            // Cleanup
            _ = storage.move(at: 0)
            _ = storage.move(at: 1)
            _ = storage.move(at: 2)
            _ = storage.move(at: 3)
        }

        @Test
        func `INV-INLINE-001d: slot i is at exactly i times stride bytes`() {
            var storage = Storage<Double>.Inline<4>()
            let stride = MemoryLayout<Double>.stride

            storage.initialize(to: 1.0, at: 0)
            storage.initialize(to: 2.0, at: 1)
            storage.initialize(to: 3.0, at: 2)
            storage.initialize(to: 4.0, at: 3)

            let ptr0: UnsafeMutablePointer<Double> = unsafe storage.pointer(at: 0)
            let ptr1: UnsafeMutablePointer<Double> = unsafe storage.pointer(at: 1)
            let ptr2: UnsafeMutablePointer<Double> = unsafe storage.pointer(at: 2)
            let ptr3: UnsafeMutablePointer<Double> = unsafe storage.pointer(at: 3)

            let base = UnsafeRawPointer(ptr0)
            unsafe #expect(UnsafeRawPointer(ptr0) == base.advanced(by: 0 * stride))
            unsafe #expect(UnsafeRawPointer(ptr1) == base.advanced(by: 1 * stride))
            unsafe #expect(UnsafeRawPointer(ptr2) == base.advanced(by: 2 * stride))
            unsafe #expect(UnsafeRawPointer(ptr3) == base.advanced(by: 3 * stride))

            // Cleanup
            _ = storage.move(at: 0)
            _ = storage.move(at: 1)
            _ = storage.move(at: 2)
            _ = storage.move(at: 3)
        }

        @Test
        func `layout is optimal for various element types`() {
            // UInt8 - 1 byte stride
            let uint8Size = MemoryLayout<Storage<UInt8>.Inline<16>>.size
            let uint8Ideal = 16 * MemoryLayout<UInt8>.stride
            #expect(uint8Size >= uint8Ideal, "UInt8×16 must fit 16 bytes of elements")

            // Int32 - 4 byte stride
            let int32Size = MemoryLayout<Storage<Int32>.Inline<8>>.size
            let int32Ideal = 8 * MemoryLayout<Int32>.stride
            #expect(int32Size >= int32Ideal, "Int32×8 must fit 32 bytes of elements")

            // Int64 - 8 byte stride
            let int64Size = MemoryLayout<Storage<Int64>.Inline<4>>.size
            let int64Ideal = 4 * MemoryLayout<Int64>.stride
            #expect(int64Size >= int64Ideal, "Int64×4 must fit 32 bytes of elements")
        }
    }

    // =========================================================================
    // MARK: - INV-INLINE-002: Initialization State Invariants (BitVector Auto-Tracking)
    // =========================================================================

    @Suite("INV-INLINE-002: Initialization State (Auto-Tracking)")
    struct InitializationState {

        @Test
        func `INV-INLINE-002a: storage starts empty on construction`() {
            let storage = Storage<Int>.Inline<8>()
            #expect(storage.isEmpty == true)
            #expect(storage.initializedCount == 0)
        }

        @Test
        func `INV-INLINE-002b: initialize automatically sets slot bit`() {
            var storage = Storage<Int>.Inline<4>()

            #expect(storage.isEmpty == true)

            storage.initialize(to: 42, at: 0)
            #expect(storage.initializedCount == 1, "initialize should set bit")
            #expect(storage.isEmpty == false)

            storage.initialize(to: 100, at: 2)
            #expect(storage.initializedCount == 2, "initialize should set another bit")

            // Cleanup
            _ = storage.move(at: 0)
            _ = storage.move(at: 2)
        }

        @Test
        func `INV-INLINE-002c: move automatically clears slot bit`() {
            var storage = Storage<Int>.Inline<4>()

            storage.initialize(to: 42, at: 0)
            storage.initialize(to: 84, at: 1)
            #expect(storage.initializedCount == 2)

            _ = storage.move(at: 0)
            #expect(storage.initializedCount == 1, "move should clear bit")

            _ = storage.move(at: 1)
            #expect(storage.isEmpty == true, "all bits should be cleared")
        }

        @Test
        func `INV-INLINE-002d: deinitialize at slot clears bit`() {
            var storage = Storage<Int>.Inline<4>()

            storage.initialize(to: 42, at: 0)
            storage.initialize(to: 84, at: 1)
            #expect(storage.initializedCount == 2)

            storage.deinitialize(at: 0)
            #expect(storage.initializedCount == 1, "deinitialize should clear bit")

            storage.deinitialize(at: 1)
            #expect(storage.isEmpty == true)
        }

        @Test
        func `INV-INLINE-002e: deinitialize range clears multiple bits`() {
            var storage = Storage<Int>.Inline<8>()

            // Initialize slots 0-4
            for i in 0..<5 {
                storage.initialize(to: i * 10, at: try! Index<Int>(i))
            }
            #expect(storage.initializedCount == 5)

            // Deinitialize range 1..<4
            let range: Swift.Range<Index<Int>> = 1..<4
            storage.deinitialize(range: range)
            #expect(storage.initializedCount == 2, "3 bits should be cleared")

            // Cleanup remaining: 0 and 4
            _ = storage.move(at: 0)
            _ = storage.move(at: 4)
            #expect(storage.isEmpty == true)
        }

        @Test
        func `INV-INLINE-002f: deinit cleans up all tracked slots`() {
            final class Tracker: @unchecked Sendable {
                nonisolated(unsafe) static var count = 0
                init() { unsafe Tracker.count += 1 }
                deinit { unsafe Tracker.count -= 1 }
            }

            unsafe Tracker.count = 0

            do {
                var storage = Storage<Tracker>.Inline<4>()

                storage.initialize(to: Tracker(), at: 0)
                storage.initialize(to: Tracker(), at: 1)
                storage.initialize(to: Tracker(), at: 2)

                unsafe #expect(Tracker.count == 3)
                #expect(storage.initializedCount == 3)
                // storage goes out of scope - deinit iterates set bits and cleans up
            }

            unsafe #expect(Tracker.count == 0, "all trackers should be deinitialized by deinit")
        }

        @Test
        func `INV-INLINE-002g: sparse initialization pattern tracked correctly`() {
            final class Tracker: @unchecked Sendable {
                nonisolated(unsafe) static var deinitCount = 0
                deinit { unsafe Tracker.deinitCount += 1 }
            }

            unsafe Tracker.deinitCount = 0

            do {
                var storage = Storage<Tracker>.Inline<8>()

                // Initialize sparse slots: 1, 3, 5, 7
                storage.initialize(to: Tracker(), at: 1)
                storage.initialize(to: Tracker(), at: 3)
                storage.initialize(to: Tracker(), at: 5)
                storage.initialize(to: Tracker(), at: 7)

                #expect(storage.initializedCount == 4)
                // deinit should clean up exactly these 4 slots
            }

            unsafe #expect(Tracker.deinitCount == 4, "exactly 4 sparse slots should be deinitialized")
        }
    }

    // =========================================================================
    // MARK: - INV-INLINE-004: Ownership Invariants
    // =========================================================================

    @Suite("INV-INLINE-004: Ownership")
    struct Ownership {

        @Test
        func `INV-INLINE-004d: move transfers ownership and deinitializes slot`() {
            final class Tracker: @unchecked Sendable {
                nonisolated(unsafe) static var instances = 0
                init() { unsafe Tracker.instances += 1 }
                deinit { unsafe Tracker.instances -= 1 }
            }

            unsafe Tracker.instances = 0

            var storage = Storage<Tracker>.Inline<4>()
            storage.initialize(to: Tracker(), at: 0)

            unsafe #expect(Tracker.instances == 1)

            // Move transfers ownership - tracker still exists but in different location
            let moved = storage.move(at: 0)
            unsafe #expect(Tracker.instances == 1, "move should transfer, not destroy")

            // Dropping moved value destroys it
            _ = consume moved
            unsafe #expect(Tracker.instances == 0)
        }

        @Test
        func `INV-INLINE-004e: initialize consumes the element`() {
            final class Tracker: @unchecked Sendable {
                nonisolated(unsafe) static var instances = 0
                init() { unsafe Tracker.instances += 1 }
                deinit { unsafe Tracker.instances -= 1 }
            }

            unsafe Tracker.instances = 0

            var storage = Storage<Tracker>.Inline<4>()

            // Create tracker - count goes to 1
            let tracker = Tracker()
            unsafe #expect(Tracker.instances == 1)

            // Initialize consumes tracker - it now lives in storage.
            // If initialize copied instead of consuming, instances would be 2.
            storage.initialize(to: tracker, at: 0)
            unsafe #expect(Tracker.instances == 1, "initialize consumes, doesn't copy")

            // Cleanup: move element out of storage.
            // Note: We cannot assert instances == 0 here because `consume` does not
            // guarantee immediate deinit for class types. For Copyable references,
            // deinit timing is ARC-managed and may be deferred to end of scope.
            // See: https://forums.swift.org/t/should-deinit-be-called-after-explicit-consume-of-reference-type/66920
            _ = storage.move(at: 0)
        }
    }

    // =========================================================================
    // MARK: - INV-INLINE-005: Initialization Enum Invariants (for Heap storage)
    // =========================================================================

    @Suite("INV-INLINE-005: Initialization Enum (Heap)")
    struct InitializationEnum {

        @Test
        func `INV-INLINE-005c: empty semantics - zero initialized slots`() {
            let empty: Storage<Int>.Initialization = .empty
            #expect(empty.isEmpty)
            #expect(empty.count == 0)
        }

        @Test
        func `INV-INLINE-005d: one semantics - contiguous range count`() {
            let range: Swift.Range<Index<Int>> = 2..<7
            let one: Storage<Int>.Initialization = .one(range)

            #expect(!one.isEmpty)
            #expect(one.count == 5)
        }

        @Test
        func `INV-INLINE-005e: two semantics - disjoint ranges for ring buffer`() {
            // Simulates ring buffer wrap: elements at [0,3) and [6,8)
            let first: Swift.Range<Index<Int>> = 0..<3
            let second: Swift.Range<Index<Int>> = 6..<8

            let two: Storage<Int>.Initialization = .two(first: first, second: second)

            #expect(!two.isEmpty)
            #expect(two.count == 5, "3 + 2 = 5 total elements")
        }

        @Test
        func `linear factory creates correct one-range state`() {
            let linear0: Storage<Int>.Initialization = .linear(count: 0)
            #expect(linear0.isEmpty)

            let linear5: Storage<Int>.Initialization = .linear(count: 5)
            #expect(!linear5.isEmpty)
            #expect(linear5.count == 5)

            // Verify it's actually a .one case starting at zero
            if case .one(let range) = linear5 {
                #expect(range.lowerBound == 0)
                #expect(range.upperBound == 5)
            } else {
                Issue.record("linear(count:) should produce .one case")
            }
        }

        @Test
        func `heap two-span deinitialize cleans up both ranges correctly`() {
            final class Tracker: @unchecked Sendable {
                let id: Int
                nonisolated(unsafe) static var deinitOrder: [Int] = []
                init(_ id: Int) { self.id = id }
                deinit { unsafe Tracker.deinitOrder.append(id) }
            }

            unsafe Tracker.deinitOrder = []

            let heap = Storage<Tracker>.Heap.create(minimumCapacity: 8)

            // Initialize two disjoint ranges: [0,2) and [5,7)
            heap.initialize(to: Tracker(0), at: 0)
            heap.initialize(to: Tracker(1), at: 1)
            heap.initialize(to: Tracker(5), at: 5)
            heap.initialize(to: Tracker(6), at: 6)

            let first: Swift.Range<Index<Tracker>> = 0..<2
            let second: Swift.Range<Index<Tracker>> = 5..<7
            heap.initialization = .two(first: first, second: second)

            heap.deinitialize()

            unsafe #expect(Tracker.deinitOrder.count == 4)
            // First range deinitialized first
            unsafe #expect(Tracker.deinitOrder[0] == 0)
            unsafe #expect(Tracker.deinitOrder[1] == 1)
            // Second range deinitialized second
            unsafe #expect(Tracker.deinitOrder[2] == 5)
            unsafe #expect(Tracker.deinitOrder[3] == 6)
        }
    }

    // =========================================================================
    // MARK: - INV-INLINE-006: Cross-Storage Operation Invariants
    // =========================================================================

    @Suite("INV-INLINE-006: Cross-Storage Operations")
    struct CrossStorageOperations {

        @Test
        func `INV-INLINE-006a: move to heap linearizes to destination 0 to count`() {
            var inline = Storage<Int>.Inline<8>()
            let heap = Storage<Int>.Heap.create(minimumCapacity: 8)

            // Initialize at non-zero slots
            inline.initialize(to: 100, at: 2)
            inline.initialize(to: 200, at: 3)
            inline.initialize(to: 300, at: 4)

            let range: Swift.Range<Index<Int>> = 2..<5
            inline.move(range: range, to: heap)
            heap.initialization = .linear(count: 3)

            // Verify destination has values at 0, 1, 2 (linearized)
            #expect(heap.move(at: 0) == 100)
            #expect(heap.move(at: 1) == 200)
            #expect(heap.move(at: 2) == 300)
            heap.initialization = .empty

            // Inline bits should be cleared after move
            #expect(inline.isEmpty == true)
        }

        @Test
        func `INV-INLINE-006b: copy to heap linearizes to destination 0 to count`() {
            var inline = Storage<Int>.Inline<8>()
            let heap = Storage<Int>.Heap.create(minimumCapacity: 8)

            // Initialize at non-zero slots
            inline.initialize(to: 10, at: 3)
            inline.initialize(to: 20, at: 4)

            let range: Swift.Range<Index<Int>> = 3..<5
            inline.copy(range: range, to: heap)
            heap.initialization = .linear(count: 2)

            // Verify destination has values at 0, 1 (linearized)
            #expect(heap.move(at: 0) == 10)
            #expect(heap.move(at: 1) == 20)
            heap.initialization = .empty

            // Inline should still have values (copy doesn't remove)
            #expect(inline.initializedCount == 2)

            // Cleanup inline
            _ = inline.move(at: 3)
            _ = inline.move(at: 4)
        }

        @Test
        func `INV-INLINE-006c: move deinitializes source slots`() {
            final class Tracker: @unchecked Sendable {
                nonisolated(unsafe) static var instances = 0
                init() { unsafe Tracker.instances += 1 }
                deinit { unsafe Tracker.instances -= 1 }
            }

            unsafe Tracker.instances = 0

            var inline = Storage<Tracker>.Inline<4>()
            let heap = Storage<Tracker>.Heap.create(minimumCapacity: 4)

            inline.initialize(to: Tracker(), at: 0)
            inline.initialize(to: Tracker(), at: 1)

            unsafe #expect(Tracker.instances == 2)
            #expect(inline.initializedCount == 2)

            let range: Swift.Range<Index<Tracker>> = 0..<2
            inline.move(range: range, to: heap)
            heap.initialization = .linear(count: 2)

            // Count should still be 2 - moved, not destroyed
            unsafe #expect(Tracker.instances == 2)
            // Inline bits should be cleared
            #expect(inline.isEmpty == true)

            // Cleanup heap
            _ = heap.move(at: 0)
            _ = heap.move(at: 1)
            heap.initialization = .empty

            unsafe #expect(Tracker.instances == 0)
        }

        @Test
        func `INV-INLINE-006d: copy preserves source slots`() {
            var inline = Storage<Int>.Inline<4>()
            let heap = Storage<Int>.Heap.create(minimumCapacity: 4)

            inline.initialize(to: 42, at: 0)
            inline.initialize(to: 84, at: 1)

            let range: Swift.Range<Index<Int>> = 0..<2
            inline.copy(range: range, to: heap)
            heap.initialization = .linear(count: 2)

            // Source should still have values and bits set
            #expect(inline.initializedCount == 2)
            let val0 = inline.move(at: 0)
            let val1 = inline.move(at: 1)
            #expect(val0 == 42, "source slot 0 should be preserved")
            #expect(val1 == 84, "source slot 1 should be preserved")

            // Cleanup heap
            _ = heap.move(at: 0)
            _ = heap.move(at: 1)
            heap.initialization = .empty
        }

        @Test
        func `empty range operations are no-ops`() {
            var inline = Storage<Int>.Inline<4>()
            let heap = Storage<Int>.Heap.create(minimumCapacity: 4)

            let emptyRange: Swift.Range<Index<Int>> = Index<Int>.zero..<Index<Int>.zero

            // These should not crash or do anything
            inline.move(range: emptyRange, to: heap)
            inline.copy(range: emptyRange, to: heap)

            #expect(heap.initialization.isEmpty)
        }
    }

    // =========================================================================
    // MARK: - INV-INLINE-008: Capacity Invariants
    // =========================================================================

    @Suite("INV-INLINE-008: Capacity")
    struct Capacity {

        @Test
        func `INV-INLINE-008a: capacity is compile-time fixed`() {
            // Different capacities produce different types
            let storage4 = Storage<Int>.Inline<4>()
            let storage8 = Storage<Int>.Inline<8>()

            // Type system ensures capacity - we verify via layout
            let size4 = MemoryLayout<Storage<Int>.Inline<4>>.size
            let size8 = MemoryLayout<Storage<Int>.Inline<8>>.size

            // Size 8 should be larger than size 4
            #expect(size8 > size4, "capacity 8 should have larger size than capacity 4")

            _ = storage4
            _ = storage8
        }

        @Test
        func `all slots in 0 to capacity are accessible`() {
            var storage = Storage<Int>.Inline<4>()

            // Can access all slots 0..<4
            storage.initialize(to: 0, at: 0)
            storage.initialize(to: 1, at: 1)
            storage.initialize(to: 2, at: 2)
            storage.initialize(to: 3, at: 3)

            #expect(storage.initializedCount == 4)

            #expect(storage.move(at: 0) == 0)
            #expect(storage.move(at: 1) == 1)
            #expect(storage.move(at: 2) == 2)
            #expect(storage.move(at: 3) == 3)

            #expect(storage.isEmpty == true)
        }
    }

    // =========================================================================
    // MARK: - Edge Cases
    // =========================================================================

    @Suite("Edge Cases")
    struct EdgeCases {

        @Test
        func `zero capacity storage`() {
            let storage = Storage<Int>.Inline<0>()
            #expect(storage.isEmpty == true)
            #expect(storage.initializedCount == 0)
            // No slots to access - just verify construction works
        }

        @Test
        func `single element capacity`() {
            var storage = Storage<Int>.Inline<1>()

            storage.initialize(to: 42, at: 0)
            #expect(storage.initializedCount == 1)
            #expect(storage.move(at: 0) == 42)
            #expect(storage.isEmpty == true)
        }

        @Test
        func `large element type`() {
            struct LargeStruct {
                var a: Int64
                var b: Int64
                var c: Int64
                var d: Int64
                var e: Int64
                var f: Int64
                var g: Int64
                var h: Int64
            }

            var storage = Storage<LargeStruct>.Inline<2>()

            let large = LargeStruct(a: 1, b: 2, c: 3, d: 4, e: 5, f: 6, g: 7, h: 8)
            storage.initialize(to: large, at: 0)
            #expect(storage.initializedCount == 1)

            let retrieved = storage.move(at: 0)
            #expect(retrieved.a == 1)
            #expect(retrieved.h == 8)
            #expect(storage.isEmpty == true)
        }

        @Test
        func `deinitialize empty range is no-op`() {
            var storage = Storage<Int>.Inline<4>()
            storage.initialize(to: 42, at: 0)
            #expect(storage.initializedCount == 1)

            let emptyRange: Swift.Range<Index<Int>> = Index<Int>.zero..<Index<Int>.zero
            storage.deinitialize(range: emptyRange)

            // Original value should still be there
            #expect(storage.initializedCount == 1)
            #expect(storage.move(at: 0) == 42)
        }

        @Test
        func `deinit with no initialized slots is safe`() {
            // This test verifies the deinit doesn't crash when nothing is initialized
            do {
                let storage = Storage<Int>.Inline<4>()
                #expect(storage.isEmpty == true)
                // storage goes out of scope - deinit runs with empty bitvector
            }
            // If we get here, deinit didn't crash
        }

        @Test
        func `maximum supported capacity 256`() {
            var storage = Storage<UInt8>.Inline<256>()

            // Initialize first and last slots
            storage.initialize(to: 0, at: 0)
            storage.initialize(to: 255, at: 255)

            #expect(storage.initializedCount == 2)

            #expect(storage.move(at: 0) == 0)
            #expect(storage.move(at: 255) == 255)
            #expect(storage.isEmpty == true)
        }
    }
}
