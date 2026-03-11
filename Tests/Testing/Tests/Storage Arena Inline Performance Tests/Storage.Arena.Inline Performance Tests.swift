import Testing
import Storage_Arena_Inline_Primitives
import Storage_Primitives_Test_Support

@Suite(.serialized)
struct `Storage.Arena.Inline - Performance` {

    // MARK: - Allocation Throughput

    @Test(.timed(iterations: 20, warmup: 3))
    func `allocate 256 slots`() {
        var arena = Storage<Int>.Arena.Inline<256>()
        for _ in 0..<256 {
            _ = arena.allocate()
        }
    }

    // MARK: - Pointer Access

    @Test(.timed(iterations: 20, warmup: 3))
    func `pointer write-read 256 slots`() {
        var arena = Storage<Int>.Arena.Inline<256>()
        var slots: [Index<Int>.Bounded<256>] = []
        slots.reserveCapacity(256)
        for _ in 0..<256 {
            slots.append(arena.allocate()!)
        }
        for (i, slot) in slots.enumerated() {
            unsafe arena.pointer(at: slot).initialize(to: i)
        }
        var sum = 0
        for slot in slots {
            sum &+= unsafe arena.pointer(at: slot).pointee
        }
        _ = sum
        arena.deinitialize.all()
    }

    // MARK: - Deinitialize

    @Test(.timed(iterations: 20, warmup: 3))
    func `deinitialize.all 256 slots`() {
        var arena = Storage<Int>.Arena.Inline<256>()
        for i in 0..<256 {
            let slot = arena.allocate()!
            unsafe arena.pointer(at: slot).initialize(to: i)
        }
        arena.deinitialize.all()
    }

    // MARK: - Fill-Reset Cycles

    @Test(.timed(iterations: 20, warmup: 3))
    func `fill and reset 256 elements 20 cycles`() {
        var arena = Storage<Int>.Arena.Inline<256>()
        for _ in 0..<20 {
            for i in 0..<256 {
                let slot = arena.allocate()!
                unsafe arena.pointer(at: slot).initialize(to: i)
            }
            arena.deinitialize.all()
        }
    }
}
