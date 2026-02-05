// MARK: - Test using ONLY Storage_Primitives_Core
// Test basic deinit without setting initialization state

import Storage_Primitives_Core
import Index_Primitives

final class DeinitTracker: @unchecked Sendable {
    nonisolated(unsafe) static var deinitCount = 0
    deinit { unsafe DeinitTracker.deinitCount += 1 }
}

// Wrapper that we CAN see deinit for
struct Wrapper: ~Copyable {
    var storage: Storage<DeinitTracker>.Inline<2>
    let tracker: DeinitTracker

    init() {
        storage = Storage<DeinitTracker>.Inline<2>()
        tracker = DeinitTracker()
    }

    deinit {
        print("Wrapper.deinit called")
        // Note: we can't manually clean up storage._initialization because it's package-private
    }
}

func testWrapperDeinit() {
    print("Starting CoreOnly test...")
    unsafe DeinitTracker.deinitCount = 0

    do {
        let wrapper = Wrapper()
        print("Wrapper created")
        _ = wrapper
    }

    print("After scope exit: DeinitTracker.deinitCount = \(unsafe DeinitTracker.deinitCount)")

    if unsafe DeinitTracker.deinitCount >= 1 {
        print("SUCCESS: Wrapper.deinit was called!")
    } else {
        print("FAILURE: Wrapper.deinit was NOT called!")
    }
}

testWrapperDeinit()
