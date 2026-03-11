import Testing
import Storage_Arena_Primitives
import Storage_Primitives_Test_Support

@Suite(.serialized)
struct `Storage.Arena - Performance` {

    // MARK: - Initialize Throughput

    @Test(.timed(iterations: 20, warmup: 3))
    func `initialize 10_000 elements`() {
        let arena = Storage<Int>.Arena(minimumCapacity: 10_000)
        for i in 0..<10_000 {
            let slot = Index<Int>(Ordinal(UInt(i)))
            arena.initialize(to: i, at: slot)
        }
        arena.highWater = 10_000
    }

    // MARK: - Move Throughput

    @Test(.timed(iterations: 20, warmup: 3))
    func `initialize and move 10_000 elements`() {
        let arena = Storage<Int>.Arena(minimumCapacity: 10_000)
        for i in 0..<10_000 {
            let slot = Index<Int>(Ordinal(UInt(i)))
            arena.initialize(to: i, at: slot)
        }
        for i in 0..<10_000 {
            let slot = Index<Int>(Ordinal(UInt(i)))
            _ = arena.move(at: slot)
        }
    }

    // MARK: - Pointer Access

    @Test(.timed(iterations: 20, warmup: 3))
    func `pointer write-read 10_000 slots`() {
        let arena = Storage<Int>.Arena(minimumCapacity: 10_000)
        for i in 0..<10_000 {
            let slot = Index<Int>(Ordinal(UInt(i)))
            unsafe arena.pointer(at: slot).initialize(to: i)
        }
        var sum = 0
        for i in 0..<10_000 {
            let slot = Index<Int>(Ordinal(UInt(i)))
            sum &+= unsafe arena.pointer(at: slot).pointee
        }
        _ = sum
        for i in 0..<10_000 {
            arena.deinitialize(at: Index<Int>(Ordinal(UInt(i))))
        }
    }

    // MARK: - Meta Scanning

    @Test(.timed(iterations: 20, warmup: 3))
    func `meta scan 10_000 slots`() {
        let arena = Storage<Int>.Arena(minimumCapacity: 10_000)
        for i in 0..<10_000 {
            let slot = Index<Int>(Ordinal(UInt(i)))
            arena.initialize(to: i, at: slot)
            unsafe arena.meta[Int(i)].token |= 1
        }
        arena.highWater = 10_000

        var occupied = 0
        for i in 0..<10_000 {
            if unsafe arena.meta[i].isOccupied {
                occupied &+= 1
            }
        }
        _ = occupied

        for i in 0..<10_000 {
            arena.deinitialize(at: Index<Int>(Ordinal(UInt(i))))
        }
    }
}
