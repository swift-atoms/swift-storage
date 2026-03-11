import Testing
import Storage_Split_Primitives
import Storage_Primitives_Test_Support

@Suite(.serialized)
struct `Storage.Split - Performance` {

    // MARK: - Creation

    @Test(.timed(iterations: 20, warmup: 3))
    func `create split storage with 10_000 capacity`() {
        let split: Storage<Int>.Split<UInt8> = .create(capacity: 10_000)
        _ = split
    }

    // MARK: - Dual-Lane Pointer Access

    @Test(.timed(iterations: 20, warmup: 3))
    func `pointer write-read 10_000 lane slots`() {
        let split: Storage<Int>.Split<UInt8> = .create(capacity: 10_000)
        let lane = split.field.lane

        for i in 0..<10_000 {
            let slot = Index<Int>(Ordinal(UInt(i)))
            unsafe split.pointer(lane, at: slot).initialize(to: UInt8(i % 256))
        }
        var sum: UInt = 0
        for i in 0..<10_000 {
            let slot = Index<Int>(Ordinal(UInt(i)))
            sum &+= UInt(unsafe split.pointer(lane, at: slot).pointee)
        }
        _ = sum
        for i in 0..<10_000 {
            let slot = Index<Int>(Ordinal(UInt(i)))
            unsafe split.pointer(lane, at: slot).deinitialize(count: 1)
        }
    }

    @Test(.timed(iterations: 20, warmup: 3))
    func `pointer write-read 10_000 element slots`() {
        let split: Storage<Int>.Split<UInt8> = .create(capacity: 10_000)
        let element = split.field.element

        for i in 0..<10_000 {
            let slot = Index<Int>(Ordinal(UInt(i)))
            unsafe split.pointer(element, at: slot).initialize(to: i)
        }
        var sum = 0
        for i in 0..<10_000 {
            let slot = Index<Int>(Ordinal(UInt(i)))
            sum &+= unsafe split.pointer(element, at: slot).pointee
        }
        _ = sum
        for i in 0..<10_000 {
            let slot = Index<Int>(Ordinal(UInt(i)))
            unsafe split.pointer(element, at: slot).deinitialize(count: 1)
        }
    }

    // MARK: - Interleaved Lane + Element Access

    @Test(.timed(iterations: 20, warmup: 3))
    func `interleaved lane and element access 10_000 slots`() {
        let split: Storage<Int>.Split<UInt8> = .create(capacity: 10_000)
        let (lane, element) = split.field

        for i in 0..<10_000 {
            let slot = Index<Int>(Ordinal(UInt(i)))
            unsafe split.pointer(lane, at: slot).initialize(to: UInt8(i % 256))
            unsafe split.pointer(element, at: slot).initialize(to: i)
        }

        var laneSum: UInt = 0
        var elementSum = 0
        for i in 0..<10_000 {
            let slot = Index<Int>(Ordinal(UInt(i)))
            laneSum &+= UInt(unsafe split.pointer(lane, at: slot).pointee)
            elementSum &+= unsafe split.pointer(element, at: slot).pointee
        }
        _ = laneSum
        _ = elementSum

        for i in 0..<10_000 {
            let slot = Index<Int>(Ordinal(UInt(i)))
            unsafe split.pointer(lane, at: slot).deinitialize(count: 1)
            unsafe split.pointer(element, at: slot).deinitialize(count: 1)
        }
    }
}
