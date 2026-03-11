import Testing
import Storage_Slab_Primitives
import Storage_Primitives_Test_Support

@Suite(.serialized)
struct `Storage.Slab - Performance` {

    // MARK: - Creation

    @Test(.timed(iterations: 20, warmup: 3))
    func `create slab with 10_000 capacity`() {
        let slab = Storage<Int>.Slab(minimumCapacity: 10_000)
        _ = slab
    }

    // MARK: - Pointer Access

    @Test(.timed(iterations: 20, warmup: 3))
    func `pointer write-read 10_000 slots`() {
        let slab = Storage<Int>.Slab(minimumCapacity: 10_000)
        for i in 0..<10_000 {
            let slot = Index<Int>(Ordinal(UInt(i)))
            unsafe slab.pointer(at: slot).initialize(to: i)
        }
        var sum = 0
        for i in 0..<10_000 {
            let slot = Index<Int>(Ordinal(UInt(i)))
            sum &+= unsafe slab.pointer(at: slot).pointee
        }
        _ = sum
        for i in 0..<10_000 {
            let slot = Index<Int>(Ordinal(UInt(i)))
            unsafe slab.pointer(at: slot).deinitialize(count: 1)
        }
    }

    // MARK: - Bitmap Tracking

    @Test(.timed(iterations: 20, warmup: 3))
    func `bitmap set-clear 10_000 bits`() {
        let slab = Storage<Int>.Slab(minimumCapacity: 10_000)
        for i in 0..<10_000 {
            slab.bitmap[Index<Bit>(Ordinal(UInt(i)))] = true
        }
        for i in 0..<10_000 {
            slab.bitmap[Index<Bit>(Ordinal(UInt(i)))] = false
        }
    }
}
