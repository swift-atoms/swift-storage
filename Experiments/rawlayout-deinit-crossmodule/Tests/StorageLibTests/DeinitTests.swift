// MARK: - Cross-Module @_rawLayout Deinit Tests
// Purpose: Verify if deinit is called in TEST TARGET context
// Hypothesis: deinit is NOT called when type is used from a test target

import Testing
import Synchronization
import StorageLib

// ============================================================================
// MARK: - Test Infrastructure
// ============================================================================

final class ElementDeinitTracker: @unchecked Sendable {
    let _count = Atomic<Int>(0)
    var count: Int { _count.load(ordering: .relaxed) }
    func increment() { _count.wrappingAdd(1, ordering: .relaxed) }
    func reset() { _count.store(0, ordering: .relaxed) }
}

struct TrackedElement: ~Copyable {
    let value: Int
    let tracker: ElementDeinitTracker

    init(_ value: Int, tracker: ElementDeinitTracker) {
        self.value = value
        self.tracker = tracker
    }

    deinit {
        tracker.increment()
    }
}

// ============================================================================
// MARK: - Tests
// ============================================================================

@Suite("Storage.Inline Deinit Tests")
struct StorageInlineDeinitTests {

    @Test("Basic Storage.Inline deinit (test target)")
    func basicDeinit() {
        let storageDeinitTracker = DeinitTracker()

        do {
            let storage = Storage<Int>.Inline<3>(tracker: storageDeinitTracker)
            _ = storage
        }

        #expect(storageDeinitTracker.count == 1, "Storage.Inline deinit should be called")
    }

    @Test("Storage.Inline with elements (test target)")
    func withElements() {
        let storageDeinitTracker = DeinitTracker()
        let elementDeinitTracker = ElementDeinitTracker()

        do {
            var storage = Storage<TrackedElement>.Inline<3>(tracker: storageDeinitTracker)
            let ptr = storage.pointer()
            unsafe (ptr + 0).initialize(to: TrackedElement(1, tracker: elementDeinitTracker))
            unsafe (ptr + 1).initialize(to: TrackedElement(2, tracker: elementDeinitTracker))
            unsafe (ptr + 2).initialize(to: TrackedElement(3, tracker: elementDeinitTracker))
            storage.setCount(3)

            #expect(elementDeinitTracker.count == 0, "Elements should be alive before scope exit")
        }

        #expect(storageDeinitTracker.count == 1, "Storage.Inline deinit should be called")
        #expect(elementDeinitTracker.count == 3, "All elements should be deinitialized")
    }

    @Test("Local wrapper deinit (test target)")
    func localWrapper() {
        struct LocalWrapper: ~Copyable {
            var storage: Storage<Int>.Inline<3>
            let tracker: DeinitTracker

            init(tracker: DeinitTracker) {
                self.storage = Storage<Int>.Inline<3>()
                self.tracker = tracker
            }

            deinit {
                tracker.increment()
            }
        }

        let wrapperTracker = DeinitTracker()

        do {
            let wrapper = LocalWrapper(tracker: wrapperTracker)
            _ = wrapper
        }

        #expect(wrapperTracker.count == 1, "LocalWrapper deinit should be called")
    }
}
