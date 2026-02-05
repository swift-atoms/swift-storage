// MARK: - Variant 6 Tests
// Testing: External Index_Primitives dependency (exact mirror of real package)
// Expected: Unknown - this is the closest reproduction of the real failing scenario

import Testing
import Synchronization
import Index_Primitives
import Ordinal_Primitives
import Variant6_Core
import Variant6_Inline
import Variant6_Heap
import Variant6_TestSupport

final class ElementTracker: @unchecked Sendable {
    let _count = Atomic<Int>(0)
    var count: Int { _count.load(ordering: .relaxed) }
    func increment() { _count.wrappingAdd(1, ordering: .relaxed) }
}

struct TrackedElement: ~Copyable {
    let value: Int
    let tracker: ElementTracker

    init(_ value: Int, tracker: ElementTracker) {
        self.value = value
        self.tracker = tracker
    }

    deinit {
        tracker.increment()
    }
}

@Suite("Variant 6: External Index_Primitives Dependency")
struct Variant6Tests {

    @Test("Storage.Inline deinit is called")
    func storageDeinitCalled() {
        let tracker = DeinitTracker()

        do {
            let storage = Storage<Int>.Inline<3>(tracker: tracker)
            _ = storage
        }

        #expect(tracker.count == 1, "Storage.Inline deinit should be called")
    }

    @Test("Elements are deinitialized by Storage.Inline deinit")
    func elementsDeinitialized() {
        let storageTracker = DeinitTracker()
        let elementTracker = ElementTracker()

        do {
            var storage = Storage<TrackedElement>.Inline<3>(tracker: storageTracker)
            let ptr = unsafe storage.pointer()
            unsafe (ptr + 0).initialize(to: TrackedElement(1, tracker: elementTracker))
            unsafe (ptr + 1).initialize(to: TrackedElement(2, tracker: elementTracker))
            unsafe (ptr + 2).initialize(to: TrackedElement(3, tracker: elementTracker))
            storage.initialization = .linear(count: try! Index<TrackedElement>.Count(3))

            #expect(elementTracker.count == 0, "Elements should be alive before scope exit")
        }

        #expect(storageTracker.count == 1, "Storage.Inline deinit should be called")
        #expect(elementTracker.count == 3, "All elements should be deinitialized")
    }

    @Test("Storage.Inline deinit with Marker class (exact mirror of failing test)")
    func markerClassDeinit() {
        final class Marker: @unchecked Sendable {
            nonisolated(unsafe) static var instanceCount = 0
            init() { unsafe Marker.instanceCount += 1 }
            deinit { unsafe Marker.instanceCount -= 1 }
        }

        unsafe Marker.instanceCount = 0

        do {
            var storage = Storage<Marker>.Inline<2>()
            storage.initialize(to: Marker(), at: .zero)
            storage.initialize(to: Marker(), at: Index<Marker>(Ordinal(UInt(1))))
            storage.initialization = .linear(count: try! Index<Marker>.Count(2))

            unsafe #expect(Marker.instanceCount == 2)
        }

        unsafe #expect(Marker.instanceCount == 0, "Markers should be deinitialized when Storage.Inline.deinit runs")
    }
}
