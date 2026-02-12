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
import Storage_Split_Primitives
import Storage_Primitives_Test_Support

@Suite("Storage.Split Tests")
struct StorageSplitTests {

    // MARK: - Creation Tests

    @Test
    func `create with capacity`() {
        let capacity: Index<Int>.Count = 16
        let storage = Storage<Int>.Split<UInt8>.create(capacity: capacity)
        #expect(storage.slotCapacity == capacity)
    }

    @Test
    func `create with lane initialization`() {
        let capacity: Index<Int>.Count = 16
        let storage = Storage<Int>.Split<UInt8>.create(
            capacity: capacity,
            laneInitial: 0x80
        )
        #expect(storage.slotCapacity == capacity)

        // Verify all lane slots are initialized to 0x80
        let lane = storage.field.lane
        for i in 0..<16 {
            let slot = Index<Int>(Ordinal(UInt(i)))
            #expect(storage[lane, at: slot] == 0x80)
        }
    }

    // MARK: - Field Handle Tests

    @Test
    func `lane field has zero offset`() {
        let storage = Storage<Int>.Split<UInt8>.create(
            capacity: 8,
            laneInitial: 0
        )
        let lane = storage.field.lane
        #expect(lane._offset == .zero)
        #expect(lane._stride == Affine.Discrete.Ratio<UInt8, Memory>(MemoryLayout<UInt8>.stride))
    }

    @Test
    func `element field has aligned offset`() {
        let storage = Storage<Int>.Split<UInt8>.create(
            capacity: 8,
            laneInitial: 0
        )
        let element = storage.field.element
        // 8 bytes of UInt8, then aligned to Int alignment (8 bytes on 64-bit)
        let expectedOffset = Memory.Address.Offset(Memory.Address.Count(Cardinal(8)))
        #expect(element._offset == expectedOffset)
        #expect(element._stride == Affine.Discrete.Ratio<Int, Memory>(MemoryLayout<Int>.stride))
    }

    @Test
    func `element field alignment with odd lane count`() {
        let storage = Storage<Int>.Split<UInt8>.create(
            capacity: 3,
            laneInitial: 0
        )
        let element = storage.field.element
        // 3 bytes of UInt8, aligned up to 8 for Int alignment
        let expectedOffset = Memory.Address.Offset(Memory.Address.Count(Cardinal(8)))
        #expect(element._offset == expectedOffset)
    }

    @Test
    func `element field alignment with large lane`() {
        // UInt8 element, Int lane — lane is larger
        let storage = Storage<UInt8>.Split<Int>.create(capacity: 4)
        let element = storage.field.element
        // 4 Ints = 32 bytes of lane, UInt8 alignment = 1
        let expectedOffset = Memory.Address.Offset(Memory.Address.Count(Cardinal(UInt(4 * MemoryLayout<Int>.stride))))
        #expect(element._offset == expectedOffset)
    }

    // MARK: - Pointer Access Tests

    @Test
    func `pointer access for lane`() {
        let storage = Storage<Int>.Split<UInt8>.create(
            capacity: 4,
            laneInitial: 0xFF
        )
        let lane = storage.field.lane
        let slot = Index<Int>(1)

        // Read via pointer
        let value = unsafe storage.pointer(lane, at: slot).pointee
        #expect(value == 0xFF)

        // Write via pointer
        unsafe storage.pointer(lane, at: slot).pointee = 0x42
        let updated = unsafe storage.pointer(lane, at: slot).pointee
        #expect(updated == 0x42)
    }

    @Test
    func `pointer access for element`() {
        let storage = Storage<Int>.Split<UInt8>.create(
            capacity: 4,
            laneInitial: 0
        )
        let element = storage.field.element
        let slot = Index<Int>(2)

        // Initialize element via pointer
        unsafe storage.pointer(element, at: slot).initialize(to: 42)
        let value = unsafe storage.pointer(element, at: slot).pointee
        #expect(value == 42)

        // Clean up
        unsafe storage.pointer(element, at: slot).deinitialize(count: .one)
    }

    // MARK: - Subscript Tests

    @Test
    func `subscript read and write`() {
        let storage = Storage<Int>.Split<UInt8>.create(
            capacity: 8,
            laneInitial: 0x80
        )
        let lane = storage.field.lane

        // Read
        #expect(storage[lane, at: .zero] == 0x80)

        // Write
        storage[lane, at: .zero] = 0x42
        #expect(storage[lane, at: .zero] == 0x42)
    }

    @Test
    func `subscript for Copyable element`() {
        let storage = Storage<Int>.Split<UInt8>.create(
            capacity: 4,
            laneInitial: 0
        )
        let element = storage.field.element

        // Initialize first via pointer, then use subscript for read/write
        unsafe storage.pointer(element, at: .zero).initialize(to: 100)
        #expect(storage[element, at: .zero] == 100)

        storage[element, at: .zero] = 200
        #expect(storage[element, at: .zero] == 200)

        unsafe storage.pointer(element, at: .zero).deinitialize(count: .one)
    }

    // MARK: - Fill Tests

    @Test
    func `fill lane with value`() {
        let storage = Storage<Int>.Split<UInt8>.create(
            capacity: 16,
            laneInitial: 0x00
        )
        let lane = storage.field.lane

        // Fill with sentinel
        storage.fill(lane, with: 0x80)

        for i in 0..<16 {
            let slot = Index<Int>(Ordinal(UInt(i)))
            #expect(storage[lane, at: slot] == 0x80)
        }
    }

    @Test
    func `fill then overwrite`() {
        let storage = Storage<Int>.Split<UInt8>.create(
            capacity: 4,
            laneInitial: 0x80
        )
        let lane = storage.field.lane

        // Overwrite slot 2
        storage[lane, at: Index<Int>(2)] = 0x42

        // Fill resets all
        storage.fill(lane, with: 0xFF)

        for i in 0..<4 {
            let slot = Index<Int>(Ordinal(UInt(i)))
            #expect(storage[lane, at: slot] == 0xFF)
        }
    }

    // MARK: - withPointer Tests

    @Test
    func `withPointer provides contiguous access`() {
        let storage = Storage<Int>.Split<UInt8>.create(
            capacity: 4,
            laneInitial: 0x80
        )
        let lane = storage.field.lane

        // Mark slot 1 as occupied
        storage[lane, at: Index<Int>(1)] = 0x42

        unsafe storage.withPointer(lane) { ptr in
            #expect(unsafe ptr[0] == 0x80)
            #expect(unsafe ptr[1] == 0x42)
            #expect(unsafe ptr[2] == 0x80)
            #expect(unsafe ptr[3] == 0x80)
        }
    }

    // MARK: - Initialize/Move/Deinitialize Tests

    @Test
    func `initialize and move via field handle`() {
        let storage = Storage<Int>.Split<UInt8>.create(
            capacity: 4,
            laneInitial: 0x80
        )
        let element = storage.field.element
        let slot = Index<Int>(1)

        storage.initialize(element, to: 999, at: slot)
        let value = storage.move(element, at: slot)
        #expect(value == 999)
    }

    @Test
    func `initialize and deinitialize via field handle`() {
        final class Tracker: @unchecked Sendable {
            nonisolated(unsafe) static var deinitCount = 0
            deinit { unsafe Tracker.deinitCount += 1 }
        }

        unsafe Tracker.deinitCount = 0

        let storage = Storage<Tracker>.Split<UInt8>.create(
            capacity: 4,
            laneInitial: 0x80
        )
        let element = storage.field.element

        storage.initialize(element, to: Tracker(), at: .zero)
        storage.initialize(element, to: Tracker(), at: Index<Tracker>(1))

        unsafe #expect(Tracker.deinitCount == 0)

        storage.deinitialize(element, at: .zero)
        storage.deinitialize(element, at: Index<Tracker>(1))

        unsafe #expect(Tracker.deinitCount == 2)
    }

    // MARK: - Multiple Type Combination Tests

    @Test
    func `UInt8 lane with large struct element`() {
        struct LargeStruct: Equatable {
            var a: Int
            var b: Int
            var c: Int
            var d: Int
            var e: Int
        }

        let storage = Storage<LargeStruct>.Split<UInt8>.create(
            capacity: 4,
            laneInitial: 0
        )

        let element = storage.field.element
        let lane = storage.field.lane

        // Verify alignment — offset is divisible by alignment
        let offsetRaw = element._offset.vector.rawValue
        #expect(offsetRaw % MemoryLayout<LargeStruct>.alignment == 0)

        // Write lane
        storage[lane, at: .zero] = 0x42

        // Write element
        let value = LargeStruct(a: 1, b: 2, c: 3, d: 4, e: 5)
        unsafe storage.pointer(element, at: .zero).initialize(to: value)
        let read = unsafe storage.pointer(element, at: .zero).pointee
        #expect(read == value)

        // Lane is still correct
        #expect(storage[lane, at: .zero] == 0x42)

        unsafe storage.pointer(element, at: .zero).deinitialize(count: .one)
    }

    @Test
    func `Int lane with UInt8 element`() {
        // Reversed: larger lane, smaller element
        let storage = Storage<UInt8>.Split<Int>.create(capacity: 4)
        let lane = storage.field.lane
        let element = storage.field.element

        // Lane offset is 0, stride is 8
        #expect(lane._offset == .zero)
        #expect(lane._stride == Affine.Discrete.Ratio<Int, Memory>(MemoryLayout<Int>.stride))

        // Element offset is after 4 Ints = 32 bytes
        let expectedOffset = Memory.Address.Offset(Memory.Address.Count(Cardinal(UInt(4 * MemoryLayout<Int>.stride))))
        #expect(element._offset == expectedOffset)

        // Initialize and verify
        storage.initialize(lane, to: 0xDEAD, at: .zero)
        storage.initialize(element, to: 0xFF, at: .zero)

        #expect(unsafe storage.pointer(lane, at: .zero).pointee == 0xDEAD)
        #expect(unsafe storage.pointer(element, at: .zero).pointee == 0xFF)

        // No need to deinitialize trivial types
    }

    // MARK: - Immutable Pointer Tests

    @Test
    func `immutable pointer returns UnsafePointer`() {
        let storage = Storage<Int>.Split<UInt8>.create(
            capacity: 4,
            laneInitial: 0x42
        )
        let lane = storage.field.lane

        let ptr: UnsafePointer<UInt8> = unsafe storage.pointer(lane, at: .zero)
        let value = unsafe ptr.pointee
        #expect(value == 0x42)
    }
}
