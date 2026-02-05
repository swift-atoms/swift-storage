// MARK: - Variant 4 Tests
// Testing: Complex Initialization enum with Range<Index<Element>>
// Expected: Unknown - testing if complex generics cause deinit failure

import Testing
import Synchronization
import Variant4_Core
import Variant4_Extensions

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

@Suite("Variant 4: Complex Initialization Type")
struct Variant4Tests {

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
            let ptr = storage.pointer()
            unsafe (ptr + 0).initialize(to: TrackedElement(1, tracker: elementTracker))
            unsafe (ptr + 1).initialize(to: TrackedElement(2, tracker: elementTracker))
            unsafe (ptr + 2).initialize(to: TrackedElement(3, tracker: elementTracker))
            storage.initialization = .linear(count: 3)

            #expect(elementTracker.count == 0, "Elements should be alive before scope exit")
        }

        #expect(storageTracker.count == 1, "Storage.Inline deinit should be called")
        #expect(elementTracker.count == 3, "All elements should be deinitialized")
    }

    @Test("Storage.Inline deinit with Marker class (mirrors failing test)")
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
            storage.initialize(to: Marker(), at: 1)
            storage.initialization = .linear(count: 2)

            unsafe #expect(Marker.instanceCount == 2)
        }

        unsafe #expect(Marker.instanceCount == 0, "Markers should be deinitialized when Storage.Inline.deinit runs")
    }
}
