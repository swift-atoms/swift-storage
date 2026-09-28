#if Generational
import Storage
import Memory_Allocator_Pool
import Memory_Allocator
import Memory
import Testing

@Suite
struct CanonicalContainerIntegrationTests {
    @Test
    func `Generational spells the sparse pool column`() {
            var g = Storage<Memory.Allocator<Memory.Heap>.Pool>.Generational<Int>.create(slotCapacity: 2)
            let h = g.insert(9)
            let live = g.contains(h)
            #expect(live)
            let removed = g.remove(h)
            #expect(removed == 9)
        }
}
#endif
