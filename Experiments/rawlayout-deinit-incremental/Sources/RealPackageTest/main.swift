// MARK: - Test using the REAL swift-storage-primitives types
// This executable uses the actual types from the real package

import Storage_Primitives_Core
import Storage_Inline_Primitives
import Storage_Heap_Primitives
import Index_Primitives
import Ordinal_Primitives

final class Marker: @unchecked Sendable {
    nonisolated(unsafe) static var instanceCount = 0
    init() { unsafe Marker.instanceCount += 1 }
    deinit { unsafe Marker.instanceCount -= 1 }
}

func testDeinit() {
    print("Starting test...")
    unsafe Marker.instanceCount = 0

    do {
        var storage = Storage<Marker>.Inline<2>()
        storage.initialize(to: Marker(), at: .zero)
        storage.initialize(to: Marker(), at: Index<Marker>(Ordinal(UInt(1))))
        storage.initialization = .linear(count: try! Index<Marker>.Count(2))

        print("Before scope exit: Marker.instanceCount = \(unsafe Marker.instanceCount)")
        assert(unsafe Marker.instanceCount == 2, "Expected 2 markers")

        // Explicitly consume
        _ = consume storage
    }

    print("After scope exit: Marker.instanceCount = \(unsafe Marker.instanceCount)")

    if unsafe Marker.instanceCount == 0 {
        print("SUCCESS: Storage.Inline.deinit was called!")
    } else {
        print("FAILURE: Storage.Inline.deinit was NOT called! instanceCount = \(unsafe Marker.instanceCount)")
    }
}

testDeinit()
