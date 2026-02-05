// MARK: - Variant 2 Tests
// Testing: Module split with public import
// Expected: Unknown - testing if this causes deinit failure

import Testing
import Synchronization
import Variant2_Core
import Variant2_Extensions

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

@Suite("Variant 2: Module Split with Public Import")
struct Variant2Tests {

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
            storage.setCount(3)

            #expect(elementTracker.count == 0, "Elements should be alive before scope exit")
        }

        #expect(storageTracker.count == 1, "Storage.Inline deinit should be called")
        #expect(elementTracker.count == 3, "All elements should be deinitialized")
    }
}
