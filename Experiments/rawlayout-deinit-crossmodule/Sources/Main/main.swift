// MARK: - Cross-Module @_rawLayout Deinit Investigation
// Purpose: Verify if deinit is called when @_rawLayout type crosses module boundaries
// Hypothesis: deinit is NOT called when type is used from a different module
//
// Toolchain: Swift 6.2 (Xcode 26)
// Platform: macOS 26 (arm64)
//
// Result: PENDING
// Date: 2026-02-05

import StorageLib
import Synchronization

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
// MARK: - Test 1: Basic Storage.Inline deinit (cross-module)
// ============================================================================

func test1_basicDeinit() {
    print("=== Test 1: Basic Storage.Inline deinit (cross-module) ===")
    let storageDeinitTracker = DeinitTracker()

    do {
        let storage = Storage<Int>.Inline<3>(tracker: storageDeinitTracker)
        _ = storage
    }

    let result = storageDeinitTracker.count == 1
    print("Storage.Inline deinit called: \(storageDeinitTracker.count) time(s)")
    print("Result: \(result ? "CONFIRMED" : "REFUTED")")
    print()
}

// ============================================================================
// MARK: - Test 2: Storage.Inline with initialized elements (cross-module)
// ============================================================================

func test2_withElements() {
    print("=== Test 2: Storage.Inline with elements (cross-module) ===")
    let storageDeinitTracker = DeinitTracker()
    let elementDeinitTracker = ElementDeinitTracker()

    do {
        var storage = Storage<TrackedElement>.Inline<3>(tracker: storageDeinitTracker)
        let ptr = storage.pointer()
        unsafe (ptr + 0).initialize(to: TrackedElement(1, tracker: elementDeinitTracker))
        unsafe (ptr + 1).initialize(to: TrackedElement(2, tracker: elementDeinitTracker))
        unsafe (ptr + 2).initialize(to: TrackedElement(3, tracker: elementDeinitTracker))
        storage.setCount(3)

        print("Before scope exit:")
        print("  Storage deinit count: \(storageDeinitTracker.count)")
        print("  Element deinit count: \(elementDeinitTracker.count)")
    }

    print("After scope exit:")
    print("  Storage deinit count: \(storageDeinitTracker.count)")
    print("  Element deinit count: \(elementDeinitTracker.count)")

    let storageResult = storageDeinitTracker.count == 1
    let elementResult = elementDeinitTracker.count == 3
    print("Storage.Inline deinit called: \(storageResult ? "YES" : "NO")")
    print("Elements deinitialized: \(elementResult ? "YES" : "NO")")
    print("Result: \(storageResult && elementResult ? "CONFIRMED" : "REFUTED")")
    print()
}

// ============================================================================
// MARK: - Test 3: Local type with @_rawLayout (same module baseline)
// ============================================================================

// NOTE: Can't use @_rawLayout here - only enabled in StorageLib module
// This test uses a wrapper to verify cross-module vs same-module behavior

struct LocalWrapper: ~Copyable {
    var storage: Storage<Int>.Inline<3>
    let tracker: DeinitTracker

    init(tracker: DeinitTracker) {
        self.storage = Storage<Int>.Inline<3>()
        self.tracker = tracker
    }

    deinit {
        print("LocalWrapper deinit called")
        tracker.increment()
    }
}

func test3_localWrapper() {
    print("=== Test 3: Local wrapper around Storage.Inline ===")
    let wrapperTracker = DeinitTracker()

    do {
        let wrapper = LocalWrapper(tracker: wrapperTracker)
        _ = wrapper
    }

    let result = wrapperTracker.count == 1
    print("LocalWrapper deinit called: \(wrapperTracker.count) time(s)")
    print("Result: \(result ? "CONFIRMED" : "REFUTED")")
    print()
}

// ============================================================================
// MARK: - Execution
// ============================================================================

print("Cross-Module @_rawLayout Deinit Investigation")
print("=============================================")
print()

test1_basicDeinit()
test2_withElements()
test3_localWrapper()

print("=============================================")
print("Summary:")
print("If Test 1 & 2 REFUTED but Test 3 CONFIRMED:")
print("  -> Storage.Inline deinit not called cross-module (compiler bug)")
print("If all CONFIRMED:")
print("  -> deinit works cross-module, issue is elsewhere")
print("If all REFUTED:")
print("  -> deinit not working at all")
