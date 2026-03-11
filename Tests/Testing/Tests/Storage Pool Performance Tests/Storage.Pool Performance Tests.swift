import Testing
import Storage_Pool_Primitives
import Storage_Primitives_Test_Support

@Suite(.serialized)
struct `Storage.Pool - Performance` {

    // MARK: - Allocation Throughput

    @Test(.timed(iterations: 20, warmup: 3))
    func `allocate 10_000 slots`() throws {
        let pool = try Storage<Int>.Pool(capacity: 10_000)
        for _ in 0..<10_000 {
            _ = try pool.allocate()
        }
    }

    @Test(.timed(iterations: 20, warmup: 3))
    func `allocate and deallocate 10_000 slots`() throws {
        let pool = try Storage<Int>.Pool(capacity: 10_000)
        var slots: [Index<Int>] = []
        slots.reserveCapacity(10_000)
        for _ in 0..<10_000 {
            slots.append(try pool.allocate())
        }
        for slot in slots {
            try pool.deallocate(at: slot)
        }
    }

    // MARK: - Free List Reuse

    @Test(.timed(iterations: 20, warmup: 3))
    func `alternating allocate-deallocate 10_000 cycles`() throws {
        let pool = try Storage<Int>.Pool(capacity: 100)
        for _ in 0..<10_000 {
            let slot = try pool.allocate()
            try pool.deallocate(at: slot)
        }
    }

    // MARK: - Pointer Access

    @Test(.timed(iterations: 20, warmup: 3))
    func `pointer write-read 10_000 slots`() throws {
        let pool = try Storage<Int>.Pool(capacity: 10_000)
        var slots: [Index<Int>] = []
        slots.reserveCapacity(10_000)
        for i in 0..<10_000 {
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
    func `deinitialize.all 10_000 slots`() throws {
        let pool = try Storage<Int>.Pool(capacity: 10_000)
        for i in 0..<10_000 {
            let slot = try pool.allocate()
            unsafe pool.pointer(at: slot).initialize(to: i)
        }
        pool.deinitialize.all()
    }

    // MARK: - Copy

    @Test(.timed(iterations: 20, warmup: 3))
    func `copy pool with 10_000 elements`() throws {
        let pool = try Storage<Int>.Pool(capacity: 10_000)
        for i in 0..<10_000 {
            let slot = try pool.allocate()
            unsafe pool.pointer(at: slot).initialize(to: i)
        }
        let copy = pool.copy()
        _ = copy
    }
}
