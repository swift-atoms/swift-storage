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

// MARK: - Brutal Edge Case Tests
// These tests attempt to break Storage.Inline with extreme and unusual inputs.

@Suite("Storage.Inline Edge Cases")
struct StorageInlineEdgeCaseTests {

    // =========================================================================
    // MARK: - Zero-Sized Types
    // =========================================================================

    @Suite("Zero-Sized Types")
    struct ZeroSizedTypes {

        @Test
        func `zero-sized element type`() {
            // Empty struct has size 0, stride 1
            struct Empty {}

            #expect(MemoryLayout<Empty>.size == 0)
            #expect(MemoryLayout<Empty>.stride == 1)

            var storage = Storage<Empty>.Inline<8>()

            // Should be able to initialize all slots
            for i: Index<Empty> in [0, 1, 2, 3, 4, 5, 6, 7] {
                storage.initialize(to: Empty(), at: i)
            }

            #expect(storage.initializedCount == 8)

            // Should be able to move all slots
            for i: Index<Empty> in [0, 1, 2, 3, 4, 5, 6, 7] {
                _ = storage.move(at: i)
            }

            #expect(storage.isEmpty == true)
        }

        @Test
        func `zero-sized element with zero capacity`() {
            struct Empty {}
            let storage = Storage<Empty>.Inline<0>()
            #expect(storage.isEmpty == true)
        }

        @Test
        func `never type simulation - zero capacity`() {
            // Simulates a "never" scenario with zero slots
            enum Never {}
            let storage = Storage<Never>.Inline<0>()
            #expect(storage.isEmpty == true)
        }
    }

    // =========================================================================
    // MARK: - Alignment Extremes
    // =========================================================================

    @Suite("Alignment Extremes")
    struct AlignmentExtremes {

        @Test
        func `single byte alignment`() {
            var storage = Storage<UInt8>.Inline<255>()

            // Fill all slots
            var slot: Index<UInt8> = 0
            for i in 0..<255 {
                storage.initialize(to: UInt8(i), at: slot)
                slot = slot.successor.saturating()
            }

            #expect(storage.initializedCount == 255)

            // Verify all values
            slot = 0
            for i in 0..<255 {
                let value = storage.move(at: slot)
                #expect(value == UInt8(i))
                slot = slot.successor.saturating()
            }

            #expect(storage.isEmpty == true)
        }

        @Test
        func `16-byte aligned type`() {
            // SIMD types typically have 16-byte alignment
            struct Aligned16 {
                var a: SIMD4<Float>  // 16 bytes, 16-byte aligned
            }

            #expect(MemoryLayout<Aligned16>.alignment == 16)

            var storage = Storage<Aligned16>.Inline<4>()

            let value = Aligned16(a: SIMD4<Float>(1.0, 2.0, 3.0, 4.0))
            storage.initialize(to: value, at: 0)

            let retrieved = storage.move(at: 0)
            #expect(retrieved.a[0] == 1.0)
            #expect(retrieved.a[3] == 4.0)
        }

        @Test
        func `mixed alignment in sequence`() {
            // Test that pointer arithmetic handles stride correctly
            struct MixedPadding {
                var a: UInt8   // 1 byte
                var b: UInt64  // 8 bytes, forces padding
                var c: UInt8   // 1 byte
                // Total: likely 24 bytes with padding
            }

            let stride = MemoryLayout<MixedPadding>.stride
            #expect(stride >= 17, "Should have padding")

            var storage = Storage<MixedPadding>.Inline<4>()

            for i: Index<MixedPadding> in [0, 1, 2, 3] {
                storage.initialize(to: MixedPadding(a: 1, b: 2, c: 3), at: i)
            }

            // Verify pointer spacing
            let ptr0: UnsafeMutablePointer<MixedPadding> = unsafe storage.pointer(at: 0)
            let ptr1: UnsafeMutablePointer<MixedPadding> = unsafe storage.pointer(at: 1)
            let diff = unsafe UnsafeRawPointer(ptr1) - UnsafeRawPointer(ptr0)
            #expect(diff == stride)

            // Cleanup
            for i: Index<MixedPadding> in [0, 1, 2, 3] {
                _ = storage.move(at: i)
            }
        }
    }

    // =========================================================================
    // MARK: - Large Elements
    // =========================================================================

    @Suite("Large Elements")
    struct LargeElements {

        @Test
        func `element larger than cache line`() {
            // 128 bytes - larger than typical 64-byte cache line
            struct CacheBuster {
                var data: (Int64, Int64, Int64, Int64, Int64, Int64, Int64, Int64,
                           Int64, Int64, Int64, Int64, Int64, Int64, Int64, Int64) =
                    (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15)
            }

            #expect(MemoryLayout<CacheBuster>.size == 128)

            var storage = Storage<CacheBuster>.Inline<2>()

            storage.initialize(to: CacheBuster(), at: 0)
            storage.initialize(to: CacheBuster(), at: 1)

            let v0 = storage.move(at: 0)
            let v1 = storage.move(at: 1)

            #expect(v0.data.0 == 0)
            #expect(v0.data.15 == 15)
            #expect(v1.data.0 == 0)
        }

        @Test
        func `kilobyte-sized element`() {
            // 1024 bytes
            struct Kilobyte {
                var data: (
                    // 8 x 128 bytes = 1024 bytes
                    (Int64, Int64, Int64, Int64, Int64, Int64, Int64, Int64,
                     Int64, Int64, Int64, Int64, Int64, Int64, Int64, Int64),
                    (Int64, Int64, Int64, Int64, Int64, Int64, Int64, Int64,
                     Int64, Int64, Int64, Int64, Int64, Int64, Int64, Int64),
                    (Int64, Int64, Int64, Int64, Int64, Int64, Int64, Int64,
                     Int64, Int64, Int64, Int64, Int64, Int64, Int64, Int64),
                    (Int64, Int64, Int64, Int64, Int64, Int64, Int64, Int64,
                     Int64, Int64, Int64, Int64, Int64, Int64, Int64, Int64),
                    (Int64, Int64, Int64, Int64, Int64, Int64, Int64, Int64,
                     Int64, Int64, Int64, Int64, Int64, Int64, Int64, Int64),
                    (Int64, Int64, Int64, Int64, Int64, Int64, Int64, Int64,
                     Int64, Int64, Int64, Int64, Int64, Int64, Int64, Int64),
                    (Int64, Int64, Int64, Int64, Int64, Int64, Int64, Int64,
                     Int64, Int64, Int64, Int64, Int64, Int64, Int64, Int64),
                    (Int64, Int64, Int64, Int64, Int64, Int64, Int64, Int64,
                     Int64, Int64, Int64, Int64, Int64, Int64, Int64, Int64)
                )
            }

            #expect(MemoryLayout<Kilobyte>.size == 1024)

            var storage = Storage<Kilobyte>.Inline<1>()

            let kb = Kilobyte(data: (
                (1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16),
                (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
                (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
                (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
                (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
                (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
                (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
                (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,99)
            ))

            storage.initialize(to: kb, at: 0)
            let retrieved = storage.move(at: 0)

            #expect(retrieved.data.0.0 == 1)
            #expect(retrieved.data.7.15 == 99)
        }
    }

    // =========================================================================
    // MARK: - Rapid Cycles
    // =========================================================================

    @Suite("Rapid Cycles")
    struct RapidCycles {

        @Test
        func `rapid initialize-move cycles same slot`() {
            var storage = Storage<Int>.Inline<4>()

            // Hammer the same slot repeatedly
            for i in 0..<1000 {
                storage.initialize(to: i, at: 0)
                let value = storage.move(at: 0)
                #expect(value == i)
            }
        }

        @Test
        func `rapid initialize-move cycles all slots`() {
            var storage = Storage<Int>.Inline<8>()

            for round in 0..<100 {
                // Initialize all
                for i: Index<Int> in [0, 1, 2, 3, 4, 5, 6, 7] {
                    storage.initialize(to: round * 8 + Int(i.rawValue.rawValue), at: i)
                }

                #expect(storage.initializedCount == 8)

                // Move all
                for i: Index<Int> in [0, 1, 2, 3, 4, 5, 6, 7] {
                    let expected = round * 8 + Int(i.rawValue.rawValue)
                    #expect(storage.move(at: i) == expected)
                }

                #expect(storage.isEmpty == true)
            }
        }

        @Test
        func `rapid initialize-deinit cycles with tracking`() {
            final class Tracker: @unchecked Sendable {
                nonisolated(unsafe) static var liveCount = 0
                nonisolated(unsafe) static var totalCreated = 0
                init() {
                    unsafe Tracker.liveCount += 1
                    unsafe Tracker.totalCreated += 1
                }
                deinit { unsafe Tracker.liveCount -= 1 }
            }

            unsafe Tracker.liveCount = 0
            unsafe Tracker.totalCreated = 0

            for _ in 0..<100 {
                do {
                    var storage = Storage<Tracker>.Inline<4>()

                    // Initialize all slots
                    for i: Index<Tracker> in [0, 1, 2, 3] {
                        storage.initialize(to: Tracker(), at: i)
                    }

                    #expect(storage.initializedCount == 4)
                    // Storage goes out of scope, deinit cleans up
                }
            }

            unsafe #expect(Tracker.totalCreated == 400)
            unsafe #expect(Tracker.liveCount == 0)
        }
    }

    // =========================================================================
    // MARK: - Sparse Initialization (BitVector capability)
    // =========================================================================

    @Suite("Sparse Initialization")
    struct SparseInitialization {

        @Test
        func `single element ranges at boundaries`() {
            final class Tracker: @unchecked Sendable {
                let id: Int
                nonisolated(unsafe) static var deinitOrder: [Int] = []
                init(_ id: Int) { self.id = id }
                deinit { unsafe Tracker.deinitOrder.append(id) }
            }

            unsafe Tracker.deinitOrder = []

            do {
                var storage = Storage<Tracker>.Inline<8>()

                // Single element at first slot
                storage.initialize(to: Tracker(0), at: 0)
                // Single element at last slot
                storage.initialize(to: Tracker(7), at: 7)

                #expect(storage.initializedCount == 2)
            }

            unsafe #expect(Tracker.deinitOrder.count == 2)
            unsafe #expect(Tracker.deinitOrder.contains(0))
            unsafe #expect(Tracker.deinitOrder.contains(7))
        }

        @Test
        func `alternating slots`() {
            var storage = Storage<Int>.Inline<8>()

            // Initialize every other slot
            storage.initialize(to: 0, at: 0)
            storage.initialize(to: 2, at: 2)
            storage.initialize(to: 4, at: 4)
            storage.initialize(to: 6, at: 6)

            #expect(storage.initializedCount == 4)

            // Move and verify
            #expect(storage.move(at: 0) == 0)
            #expect(storage.move(at: 2) == 2)
            #expect(storage.move(at: 4) == 4)
            #expect(storage.move(at: 6) == 6)

            #expect(storage.isEmpty == true)
        }

        @Test
        func `gap of one slot between ranges`() {
            final class Tracker: @unchecked Sendable {
                nonisolated(unsafe) static var count = 0
                init() { unsafe Tracker.count += 1 }
                deinit { unsafe Tracker.count -= 1 }
            }

            unsafe Tracker.count = 0

            do {
                var storage = Storage<Tracker>.Inline<8>()

                // [0,3) and [4,7) - gap at slot 3
                storage.initialize(to: Tracker(), at: 0)
                storage.initialize(to: Tracker(), at: 1)
                storage.initialize(to: Tracker(), at: 2)
                storage.initialize(to: Tracker(), at: 4)
                storage.initialize(to: Tracker(), at: 5)
                storage.initialize(to: Tracker(), at: 6)

                unsafe #expect(Tracker.count == 6)
                #expect(storage.initializedCount == 6)
            }

            unsafe #expect(Tracker.count == 0)
        }
    }

    // =========================================================================
    // MARK: - Cross-Storage Edge Cases
    // =========================================================================

    @Suite("Cross-Storage Edge Cases")
    struct CrossStorageEdgeCases {

        @Test
        func `move entire capacity to heap`() {
            var inline = Storage<Int>.Inline<8>()
            let heap = Storage<Int>.Heap.create(minimumCapacity: 8)

            // Fill completely
            for i: Index<Int> in [0, 1, 2, 3, 4, 5, 6, 7] {
                inline.initialize(to: Int(i.rawValue.rawValue) * 11, at: i)
            }

            #expect(inline.initializedCount == 8)

            let range: Swift.Range<Index<Int>> = 0..<8
            inline.move(range: range, to: heap)
            heap.initialization = .linear(count: 8)

            #expect(inline.isEmpty == true)

            // Verify all moved correctly
            for i: Index<Int> in [0, 1, 2, 3, 4, 5, 6, 7] {
                let value = heap.move(at: i)
                #expect(value == Int(i.rawValue.rawValue) * 11)
            }
        }

        @Test
        func `move single element from last slot`() {
            var inline = Storage<Int>.Inline<8>()
            let heap = Storage<Int>.Heap.create(minimumCapacity: 8)

            inline.initialize(to: 999, at: 7)
            #expect(inline.initializedCount == 1)

            let range: Swift.Range<Index<Int>> = 7..<8
            inline.move(range: range, to: heap)
            heap.initialization = .linear(count: 1)

            #expect(inline.isEmpty == true)
            #expect(heap.move(at: 0) == 999)
        }

        @Test
        func `copy with class elements shares object identity and preserves source`() {
            final class Tracker: @unchecked Sendable {
                let id: Int
                nonisolated(unsafe) static var instances = 0
                init(_ id: Int) {
                    self.id = id
                    unsafe Tracker.instances += 1
                }
                deinit { unsafe Tracker.instances -= 1 }
            }

            unsafe Tracker.instances = 0

            var inline = Storage<Tracker>.Inline<4>()
            let heap = Storage<Tracker>.Heap.create(minimumCapacity: 4)

            inline.initialize(to: Tracker(100), at: 0)
            inline.initialize(to: Tracker(200), at: 1)

            unsafe #expect(Tracker.instances == 2, "Two objects created")

            let range: Swift.Range<Index<Tracker>> = 0..<2
            inline.copy(range: range, to: heap)
            heap.initialization = .linear(count: 2)

            // Copy creates references, not new objects
            unsafe #expect(Tracker.instances == 2, "Copy shares objects, doesn't clone")

            // Source still valid after copy (wasn't moved)
            #expect(inline.initializedCount == 2)

            // Move from inline
            let inlineRef0 = inline.move(at: 0)
            let inlineRef1 = inline.move(at: 1)
            _ = consume inlineRef0
            _ = consume inlineRef1

            unsafe #expect(Tracker.instances == 2, "Objects kept alive by heap references")

            // Move from heap - last references
            let heapRef0 = heap.move(at: 0)
            let heapRef1 = heap.move(at: 1)
            heap.initialization = .empty  // Mark heap as empty after moving

            // Verify heap had correct values
            #expect(heapRef0.id == 100)
            #expect(heapRef1.id == 200)

            // Drop last references
            _ = consume heapRef0
            _ = consume heapRef1
        }
    }

    // =========================================================================
    // MARK: - Pointer Arithmetic Stress
    // =========================================================================

    @Suite("Pointer Arithmetic Stress")
    struct PointerArithmeticStress {

        @Test
        func `verify all pointers are within storage bounds`() {
            var storage = Storage<Int64>.Inline<16>()

            // Initialize all
            var slot: Index<Int64> = 0
            for i in 0..<16 {
                storage.initialize(to: Int64(i), at: slot)
                slot = slot.successor.saturating()
            }

            // Get all pointers and verify ordering
            var pointers: [UnsafeRawPointer] = unsafe []
            slot = 0
            for _ in 0..<16 {
                let ptr: UnsafeMutablePointer<Int64> = unsafe storage.pointer(at: slot)
                unsafe pointers.append(UnsafeRawPointer(ptr))
                slot = slot.successor.saturating()
            }

            // Verify strictly increasing
            for i in 1..<16 {
                unsafe #expect(pointers[i] > pointers[i-1], "Pointer \(i) should be after pointer \(i-1)")
            }

            // Verify stride spacing
            let stride = MemoryLayout<Int64>.stride
            for i in 1..<16 {
                let diff = unsafe pointers[i] - pointers[i-1]
                #expect(diff == stride, "Pointers should be exactly stride apart")
            }

            // Cleanup
            slot = 0
            for _ in 0..<16 {
                _ = storage.move(at: slot)
                slot = slot.successor.saturating()
            }
        }

        @Test
        func `pointer modification affects correct slot only`() {
            var storage = Storage<Int>.Inline<8>()

            // Initialize with sentinel values
            for i: Index<Int> in [0, 1, 2, 3, 4, 5, 6, 7] {
                storage.initialize(to: -1, at: i)
            }

            // Modify slot 4 via pointer
            let ptr: UnsafeMutablePointer<Int> = unsafe storage.pointer(at: 4)
            unsafe ptr.pointee = 42

            // Verify only slot 4 changed
            #expect(storage.move(at: 0) == -1)
            #expect(storage.move(at: 1) == -1)
            #expect(storage.move(at: 2) == -1)
            #expect(storage.move(at: 3) == -1)
            #expect(storage.move(at: 4) == 42)
            #expect(storage.move(at: 5) == -1)
            #expect(storage.move(at: 6) == -1)
            #expect(storage.move(at: 7) == -1)
        }
    }

    // =========================================================================
    // MARK: - Memory Layout Verification
    // =========================================================================

    @Suite("Memory Layout Verification")
    struct MemoryLayoutVerification {

        @Test
        func `storage size scales with capacity`() {
            let size1 = MemoryLayout<Storage<Int>.Inline<1>>.size
            let size2 = MemoryLayout<Storage<Int>.Inline<2>>.size
            let size4 = MemoryLayout<Storage<Int>.Inline<4>>.size
            let size8 = MemoryLayout<Storage<Int>.Inline<8>>.size

            let stride = MemoryLayout<Int>.stride

            // Sizes should increase with capacity (element storage grows)
            #expect(size2 >= size1)
            #expect(size4 >= size2)
            #expect(size8 >= size4)

            // Element storage should scale roughly with capacity
            // (exact sizing depends on BitVector overhead)
            #expect(size8 - size4 >= 4 * stride - 8)  // Allow for alignment
        }

        @Test
        func `bool storage is compact`() {
            // Bool has stride 1
            let boolStorageSize = MemoryLayout<Storage<Bool>.Inline<8>>.size
            let boolIdealSize = 8 * MemoryLayout<Bool>.stride
            let bitVectorSize = 32  // 4 words = 32 bytes for tracking

            #expect(boolStorageSize <= boolIdealSize + bitVectorSize + 16,
                   "Bool storage should be compact")
        }
    }

    // =========================================================================
    // MARK: - Nested and Recursive Types
    // =========================================================================

    @Suite("Nested Types")
    struct NestedTypes {

        @Test
        func `storage containing optional`() {
            var storage = Storage<Int?>.Inline<4>()

            storage.initialize(to: nil, at: 0)
            storage.initialize(to: 42, at: 1)
            storage.initialize(to: nil, at: 2)
            storage.initialize(to: 100, at: 3)

            #expect(storage.move(at: 0) == nil)
            #expect(storage.move(at: 1) == 42)
            #expect(storage.move(at: 2) == nil)
            #expect(storage.move(at: 3) == 100)
        }

        @Test
        func `storage containing result type`() {
            enum TestError: Error { case failed }

            var storage = Storage<Result<Int, TestError>>.Inline<4>()

            storage.initialize(to: .success(1), at: 0)
            storage.initialize(to: .failure(.failed), at: 1)
            storage.initialize(to: .success(2), at: 2)
            storage.initialize(to: .failure(.failed), at: 3)

            if case .success(let v) = storage.move(at: 0) {
                #expect(v == 1)
            } else {
                Issue.record("Expected success")
            }

            if case .failure = storage.move(at: 1) {
                // Expected
            } else {
                Issue.record("Expected failure")
            }

            _ = storage.move(at: 2)
            _ = storage.move(at: 3)
        }

        @Test
        func `storage containing tuple`() {
            var storage = Storage<(Int, String, Double)>.Inline<2>()

            storage.initialize(to: (1, "hello", 3.14), at: 0)
            storage.initialize(to: (2, "world", 2.71), at: 1)

            let t0 = storage.move(at: 0)
            let t1 = storage.move(at: 1)

            #expect(t0.0 == 1)
            #expect(t0.1 == "hello")
            #expect(t0.2 == 3.14)
            #expect(t1.0 == 2)
            #expect(t1.1 == "world")
        }

        @Test
        func `storage containing array`() {
            var storage = Storage<[Int]>.Inline<2>()

            storage.initialize(to: [1, 2, 3, 4, 5], at: 0)
            storage.initialize(to: [], at: 1)

            let arr0 = storage.move(at: 0)
            let arr1 = storage.move(at: 1)

            #expect(arr0 == [1, 2, 3, 4, 5])
            #expect(arr1.isEmpty)
        }
    }

    // =========================================================================
    // MARK: - Deinitialize Edge Cases
    // =========================================================================

    @Suite("Deinitialize Edge Cases")
    struct DeinitializeEdgeCases {

        @Test
        func `deinitialize range at end of capacity`() {
            final class Tracker: @unchecked Sendable {
                nonisolated(unsafe) static var count = 0
                init() { unsafe Tracker.count += 1 }
                deinit { unsafe Tracker.count -= 1 }
            }

            unsafe Tracker.count = 0

            var storage = Storage<Tracker>.Inline<8>()

            // Initialize last 3 slots
            storage.initialize(to: Tracker(), at: 5)
            storage.initialize(to: Tracker(), at: 6)
            storage.initialize(to: Tracker(), at: 7)

            unsafe #expect(Tracker.count == 3)

            let range: Swift.Range<Index<Tracker>> = 5..<8
            storage.deinitialize(range: range)

            unsafe #expect(Tracker.count == 0)
            #expect(storage.isEmpty == true)
        }

        @Test
        func `deinitialize single slot multiple times via reinitialize`() {
            final class Tracker: @unchecked Sendable {
                nonisolated(unsafe) static var deinitCount = 0
                deinit { unsafe Tracker.deinitCount += 1 }
            }

            unsafe Tracker.deinitCount = 0

            var storage = Storage<Tracker>.Inline<4>()

            for _ in 0..<10 {
                storage.initialize(to: Tracker(), at: 0)
                storage.deinitialize(at: 0)
            }

            unsafe #expect(Tracker.deinitCount == 10)
        }

        @Test
        func `deinitialize then reinitialize`() {
            var storage = Storage<Int>.Inline<4>()

            // First round
            storage.initialize(to: 1, at: 0)
            storage.initialize(to: 2, at: 1)

            #expect(storage.initializedCount == 2)

            storage.deinitialize(at: 0)
            storage.deinitialize(at: 1)

            #expect(storage.isEmpty == true)

            // Second round - same slots
            storage.initialize(to: 10, at: 0)
            storage.initialize(to: 20, at: 1)

            #expect(storage.initializedCount == 2)

            #expect(storage.move(at: 0) == 10)
            #expect(storage.move(at: 1) == 20)
        }
    }

    // =========================================================================
    // MARK: - Capacity Boundaries
    // =========================================================================

    @Suite("Capacity Boundaries")
    struct CapacityBoundaries {

        @Test
        func `capacity 1 - minimal storage`() {
            var storage = Storage<Int>.Inline<1>()

            storage.initialize(to: 42, at: 0)
            #expect(storage.move(at: 0) == 42)

            storage.initialize(to: 100, at: 0)
            storage.deinitialize(at: 0)
            #expect(storage.isEmpty == true)
        }

        @Test
        func `capacity 256 - maximum supported`() {
            var storage = Storage<UInt8>.Inline<256>()

            // Fill with pattern
            var slot: Index<UInt8> = 0
            for i in 0..<256 {
                storage.initialize(to: UInt8(i), at: slot)
                slot = slot.successor.saturating()
            }

            #expect(storage.initializedCount == 256)

            // Verify pattern
            slot = 0
            for i in 0..<256 {
                let value = storage.move(at: slot)
                #expect(value == UInt8(i))
                slot = slot.successor.saturating()
            }

            #expect(storage.isEmpty == true)
        }

        @Test
        func `high capacity with large element`() {
            struct Large {
                var a: Int64
                var b: Int64
                var c: Int64
                var d: Int64
            }

            // 32 bytes × 32 = 1024 bytes of element storage
            var storage = Storage<Large>.Inline<32>()

            var slot: Index<Large> = 0
            for i in 0..<32 {
                storage.initialize(
                    to: Large(a: Int64(i), b: Int64(i*2), c: Int64(i*3), d: Int64(i*4)),
                    at: slot
                )
                slot = slot.successor.saturating()
            }

            #expect(storage.initializedCount == 32)

            slot = 0
            for i in 0..<32 {
                let v = storage.move(at: slot)
                #expect(v.a == Int64(i))
                #expect(v.d == Int64(i*4))
                slot = slot.successor.saturating()
            }
        }
    }
}
