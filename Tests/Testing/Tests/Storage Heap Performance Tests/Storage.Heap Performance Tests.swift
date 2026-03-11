import Testing
import Storage_Heap_Primitives
import Storage_Primitives_Test_Support

@Suite(.serialized)
struct `Storage.Heap - Performance` {

    // MARK: - Tracked Initialize Throughput

    @Test(.timed(iterations: 20, warmup: 3))
    func `initialize.next 10_000 elements`() throws {
        let storage = Storage<Int>.Heap.create(minimumCapacity: 10_000)
        for i in 0..<10_000 {
            try storage.initialize.next(to: i)
        }
        storage.deinitialize.all()
    }

    // MARK: - Tracked Move Throughput

    @Test(.timed(iterations: 20, warmup: 3))
    func `move.last 10_000 elements`() throws {
        let storage = Storage<Int>.Heap.create(minimumCapacity: 10_000)
        for i in 0..<10_000 {
            try storage.initialize.next(to: i)
        }
        for _ in 0..<10_000 {
            _ = try storage.move.last()
        }
    }

    // MARK: - Low-Level Pointer Access

    @Test(.timed(iterations: 20, warmup: 3))
    func `pointer write-read 10_000 slots`() {
        let storage = Storage<Int>.Heap.create(minimumCapacity: 10_000)
        for i in 0..<10_000 {
            let slot = Index<Int>(Ordinal(UInt(i)))
            unsafe storage.pointer(at: slot).initialize(to: i)
        }
        var sum = 0
        for i in 0..<10_000 {
            let slot = Index<Int>(Ordinal(UInt(i)))
            sum &+= unsafe storage.pointer(at: slot).pointee
        }
        _ = sum
        storage.initialization = .linear(count: 10_000)
        storage.deinitialize.all()
    }

    // MARK: - Deinitialize

    @Test(.timed(iterations: 20, warmup: 3))
    func `deinitialize.all 10_000 elements`() throws {
        let storage = Storage<Int>.Heap.create(minimumCapacity: 10_000)
        for i in 0..<10_000 {
            try storage.initialize.next(to: i)
        }
        storage.deinitialize.all()
    }

    // MARK: - Copy

    @Test(.timed(iterations: 20, warmup: 3))
    func `copy 10_000 elements`() throws {
        let storage = Storage<Int>.Heap.create(minimumCapacity: 10_000)
        for i in 0..<10_000 {
            try storage.initialize.next(to: i)
        }
        let copy = storage.copy()
        _ = copy
        storage.deinitialize.all()
    }

    // MARK: - Move Range

    @Test(.timed(iterations: 20, warmup: 3))
    func `move range 10_000 elements to new storage`() throws {
        let source = Storage<Int>.Heap.create(minimumCapacity: 10_000)
        let destination = Storage<Int>.Heap.create(minimumCapacity: 10_000)
        for i in 0..<10_000 {
            try source.initialize.next(to: i)
        }
        let range = Swift.Range<Index<Int>>(start: .zero, count: 10_000)
        source.move(range: range, to: destination)
        destination.initialization = .linear(count: 10_000)
        destination.deinitialize.all()
    }
}
