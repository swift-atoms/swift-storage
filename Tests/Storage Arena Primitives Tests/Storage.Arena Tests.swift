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
import Storage_Arena_Primitives
import Storage_Primitives_Test_Support

/// Test element with non-trivial stride for arena testing.
struct Payload: Equatable {
    var x: Int
    var y: UInt8
}

@Suite("Storage.Arena Tests")
struct StorageArenaTests {

    // MARK: - Init

    @Test("Init creates arena with correct slotCapacity")
    func initCapacity() {
        let arena = Storage<Payload>.Arena(minimumCapacity: 8)
        #expect(arena.slotCapacity >= 8)
        #expect(arena.highWater == .zero)
    }

    @Test("Meta is initialized to virgin state")
    func metaVirgin() {
        let arena = Storage<Payload>.Arena(minimumCapacity: 4)
        let meta = unsafe arena.meta
        let cap = Int(bitPattern: arena.slotCapacity)
        for i in 0..<cap {
            #expect(meta[i].token == 0)
            #expect(meta[i].link == .max)
            #expect(meta[i].isOccupied == false)
        }
    }

    // MARK: - Element Operations

    @Test("Initialize and read element via pointer")
    func initializeAndRead() {
        let arena = Storage<Payload>.Arena(minimumCapacity: 4)
        let slot = Index<Payload>(Ordinal(UInt(0)))

        arena.initialize(to: Payload(x: 42, y: 7), at: slot)

        let value = unsafe arena.pointer(at: slot).pointee
        #expect(value == Payload(x: 42, y: 7))

        arena.deinitialize(at: slot)
    }

    @Test("Move element out of slot")
    func moveElement() {
        let arena = Storage<Payload>.Arena(minimumCapacity: 4)
        let slot = Index<Payload>(Ordinal(UInt(0)))

        arena.initialize(to: Payload(x: 99, y: 1), at: slot)
        let moved = arena.move(at: slot)

        #expect(moved == Payload(x: 99, y: 1))
    }

    @Test("Multiple elements at different slots")
    func multipleElements() {
        let arena = Storage<Payload>.Arena(minimumCapacity: 8)

        for i in 0..<5 {
            let slot = Index<Payload>(Ordinal(UInt(i)))
            arena.initialize(to: Payload(x: i * 10, y: UInt8(i)), at: slot)
        }

        for i in 0..<5 {
            let slot = Index<Payload>(Ordinal(UInt(i)))
            let value = unsafe arena.pointer(at: slot).pointee
            #expect(value == Payload(x: i * 10, y: UInt8(i)))
        }

        for i in 0..<5 {
            let slot = Index<Payload>(Ordinal(UInt(i)))
            arena.deinitialize(at: slot)
        }
    }

    // MARK: - Meta Access

    @Test("Meta read and write")
    func metaReadWrite() {
        let arena = Storage<Payload>.Arena(minimumCapacity: 4)
        let meta = unsafe arena.meta

        // Initially virgin
        #expect(meta[0].token == 0)
        #expect(meta[0].isOccupied == false)

        // Simulate allocation: set odd token
        meta[0].token = 1
        #expect(meta[0].isOccupied == true)

        // Simulate deallocation: set even token
        meta[0].token = 2
        #expect(meta[0].isOccupied == false)
    }

    // MARK: - HighWater

    @Test("HighWater get and set")
    func highWater() {
        let arena = Storage<Payload>.Arena(minimumCapacity: 4)
        #expect(arena.highWater == .zero)

        arena.highWater = Index<Payload>.Count(Cardinal(UInt(2)))
        #expect(arena.highWater == Index<Payload>.Count(Cardinal(UInt(2))))
    }

    // MARK: - Deinit Cleanup

    @Test("Deinit deinitializes occupied elements")
    func deinitCleanup() {
        nonisolated(unsafe) var deinitCount = 0

        final class Tracker {
            let onDeinit: () -> Void
            init(onDeinit: @escaping () -> Void) {
                self.onDeinit = onDeinit
            }
            deinit { onDeinit() }
        }

        do {
            let arena = Storage<Tracker>.Arena(minimumCapacity: 4)
            let meta = unsafe arena.meta

            // Initialize two elements and mark them as occupied
            let slot0 = Index<Tracker>(Ordinal(UInt(0)))
            let slot1 = Index<Tracker>(Ordinal(UInt(1)))

            arena.initialize(to: Tracker(onDeinit: { deinitCount += 1 }), at: slot0)
            meta[0].token = 1  // mark occupied

            arena.initialize(to: Tracker(onDeinit: { deinitCount += 1 }), at: slot1)
            meta[1].token = 1  // mark occupied

            arena.highWater = Index<Tracker>.Count(Cardinal(UInt(2)))

            // Arena goes out of scope here — deinit should clean up
        }

        #expect(deinitCount == 2)
    }

    @Test("Deinit skips free slots")
    func deinitSkipsFree() {
        nonisolated(unsafe) var deinitCount = 0

        final class Tracker {
            let onDeinit: () -> Void
            init(onDeinit: @escaping () -> Void) {
                self.onDeinit = onDeinit
            }
            deinit { onDeinit() }
        }

        do {
            let arena = Storage<Tracker>.Arena(minimumCapacity: 4)
            let meta = unsafe arena.meta

            // Initialize one occupied and one free
            let slot0 = Index<Tracker>(Ordinal(UInt(0)))
            let slot1 = Index<Tracker>(Ordinal(UInt(1)))

            arena.initialize(to: Tracker(onDeinit: { deinitCount += 1 }), at: slot0)
            meta[0].token = 1  // occupied

            arena.initialize(to: Tracker(onDeinit: { deinitCount += 1 }), at: slot1)
            // Move out slot1 so it's deinitialized, then mark free
            _ = arena.move(at: slot1)
            meta[1].token = 2  // free (even)

            arena.highWater = Index<Tracker>.Count(Cardinal(UInt(2)))
        }

        // slot1 deinitialized by move+discard, slot0 by arena deinit
        #expect(deinitCount == 2)
    }

    // MARK: - Layout

    @Test("Element region offset is properly aligned")
    func layoutAlignment() {
        let cap = Index<Payload>.Count(Cardinal(UInt(10)))
        let offset = Storage<Payload>.Arena._elementRegionOffset(capacity: cap)
        let elementAlignment = try! Memory.Alignment(max(MemoryLayout<Payload>.alignment, 1))
        #expect(elementAlignment.align.up(offset) == offset)
        let metaBytes: Memory.Address.Count = cap.retag(Storage<Payload>.Arena.Meta.self) * .stride
        #expect(offset >= metaBytes)
    }

    @Test("Total bytes covers meta and elements")
    func totalBytes() {
        let cap = Index<Payload>.Count(Cardinal(UInt(10)))
        let total = Storage<Payload>.Arena._totalBytes(capacity: cap)
        let offset = Storage<Payload>.Arena._elementRegionOffset(capacity: cap)
        let elementBytes: Memory.Address.Count = cap * .stride
        #expect(total == offset + elementBytes)
    }
}
