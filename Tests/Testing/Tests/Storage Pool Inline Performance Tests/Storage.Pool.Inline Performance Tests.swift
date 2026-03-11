import Testing
import Storage_Pool_Inline_Primitives
import Storage_Primitives_Test_Support

@Suite(.serialized)
struct `Storage.Pool.Inline - Performance` {

    // MARK: - Allocation Throughput

    @Test(.timed(iterations: 20, warmup: 3))
    func `allocate 256 slots`() throws {
        var pool = Storage<Int>.Pool.Inline<256>()
        for _ in 0..<256 {
            _ = try pool.allocate()
        }
    }

    @Test(.timed(iterations: 20, warmup: 3))
    func `allocate and deallocate 256 slots`() throws {
        var pool = Storage<Int>.Pool.Inline<256>()
        var slots: [Index<Int>.Bounded<256>] = []
        slots.reserveCapacity(256)
        for _ in 0..<256 {
            slots.append(try pool.allocate())
        }
        for slot in slots {
            try pool.deallocate(at: slot)
        }
    }

    // MARK: - Rapid Cycling

    @Test(.timed(iterations: 20, warmup: 3))
    func `alternating allocate-deallocate 10_000 cycles`() throws {
        var pool = Storage<Int>.Pool.Inline<256>()
        for _ in 0..<10_000 {
            let slot = try pool.allocate()
            try pool.deallocate(at: slot)
        }
    }

    // MARK: - Pointer Access

    @Test(.timed(iterations: 20, warmup: 3))
    func `pointer write-read 256 slots`() throws {
        var pool = Storage<Int>.Pool.Inline<256>()
        var slots: [Index<Int>.Bounded<256>] = []
        slots.reserveCapacity(256)
        for i in 0..<256 {
            let slot = try pool.allocate()
            slots.append(slot)
            unsafe pool.pointer(at: slot).initialize(to: i)
        }
        var sum = 0
        for slot in slots {
            sum &+= unsafe pool.pointer(at: slot).pointee
        }
        _ = sum
        pool.deinitialize.all()
    }

    // MARK: - Deinitialize

    @Test(.timed(iterations: 20, warmup: 3))
    func `deinitialize.all 256 slots`() throws {
        var pool = Storage<Int>.Pool.Inline<256>()
        for i in 0..<256 {
            let slot = try pool.allocate()
            unsafe pool.pointer(at: slot).initialize(to: i)
        }
        pool.deinitialize.all()
    }
}
