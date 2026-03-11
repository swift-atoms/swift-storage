import Testing
import Storage_Inline_Primitives
import Storage_Primitives_Test_Support

@Suite(.serialized)
struct `Storage.Inline - Performance` {

    // MARK: - Tracked Initialize Throughput

    @Test(.timed(iterations: 20, warmup: 3))
    func `initialize.next 256 elements`() throws {
        var storage = Storage<Int>.Inline<256>()
        for i in 0..<256 {
            try storage.initialize.next(to: i)
        }
        storage.deinitialize.all()
    }

    // MARK: - Tracked Move Throughput

    @Test(.timed(iterations: 20, warmup: 3))
    func `move.last 256 elements`() throws {
        var storage = Storage<Int>.Inline<256>()
        for i in 0..<256 {
            try storage.initialize.next(to: i)
        }
        for _ in 0..<256 {
            _ = try storage.move.last()
        }
    }

    // MARK: - Pointer Access

    @Test(.timed(iterations: 20, warmup: 3))
    func `pointer write-read 256 slots`() {
        var storage = Storage<Int>.Inline<256>()
        for i in 0..<256 {
            let slot = Index<Int>.Bounded<256>(Index<Int>(Ordinal(UInt(i))))!
            unsafe storage.pointer(at: slot).initialize(to: i)
        }
        var sum = 0
        for i in 0..<256 {
            let slot = Index<Int>.Bounded<256>(Index<Int>(Ordinal(UInt(i))))!
            sum &+= unsafe storage.pointer(at: slot).pointee
        }
        _ = sum
        storage.deinitialize.all()
    }

    // MARK: - Deinitialize

    @Test(.timed(iterations: 20, warmup: 3))
    func `deinitialize.all 256 elements`() throws {
        var storage = Storage<Int>.Inline<256>()
        for i in 0..<256 {
            try storage.initialize.next(to: i)
        }
        storage.deinitialize.all()
    }

    // MARK: - Fill-Reset Cycles

    @Test(.timed(iterations: 20, warmup: 3))
    func `fill and reset 256 elements 20 cycles`() throws {
        var storage = Storage<Int>.Inline<256>()
        for _ in 0..<20 {
            for i in 0..<256 {
                try storage.initialize.next(to: i)
            }
            storage.deinitialize.all()
        }
    }
}
