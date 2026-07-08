import Index_Primitives
import Store_Primitives
import Testing

// MARK: - A minimal in-test ledgered conformer (the real conformers — Storage.Contiguous,
// Store.Inline — live in swift-storage-primitives and run the composed disciplines there)

private struct TwoSlot: Store.Ledgered.`Protocol` {
    var slots: [Int?] = [nil, nil]
    var initialization: Store.Initialization<Int> = .empty
}

extension TwoSlot {
    var capacity: Index<Int>.Count { Index<Int>.Count(UInt(2)) }

    // Test-fixture contract: the caller only reads initialized slots.
    // swift-format-ignore: NeverForceUnwrap
    subscript(slot: Index<Int>) -> Int {
        get { slots[Int(bitPattern: Index<Int>.Count(slot))]! }
        set { slots[Int(bitPattern: Index<Int>.Count(slot))] = newValue }
    }

    mutating func initialize(at slot: Index<Int>, to element: consuming Int) {
        slots[Int(bitPattern: Index<Int>.Count(slot))] = element
    }

    mutating func move(at slot: Index<Int>) -> Int {
        let n = Int(bitPattern: Index<Int>.Count(slot))
        defer { slots[n] = nil }
        // Test-fixture contract: the caller only moves initialized slots.
        // swift-format-ignore: NeverForceUnwrap
        return slots[n]!
    }
}

/// A composing discipline's bulk-sync, generic over the ratified bound.
private func relabel<S: Store.Ledgered.`Protocol` & ~Copyable>(
    _ store: inout S,
    to shape: Store.Initialization<S.Element>
) {
    store.initialization = shape
}

@Suite
struct `Store Ledgered Tests` {

    @Test
    func `the settable ledger requirement is generically writable and readable`() {
        var store = TwoSlot()
        store.initialize(at: Index<Int>(Ordinal(UInt(0))), to: 7)
        let one = Index<Int>(Ordinal(UInt(0)))..<Index<Int>(Ordinal(UInt(1)))
        relabel(&store, to: .one(one))
        #expect(store.initialization == .one(one))
        relabel(&store, to: .empty)
        #expect(store.initialization == .empty)
    }

    @Test
    func `the refinement is a Store.Protocol (seam ops reachable through the bound)`() {
        var store = TwoSlot()
        store.unshare()  // the defaulted gate rides along
        store.initialize(at: Index<Int>(Ordinal(UInt(1))), to: 9)
        let read = store[Index<Int>(Ordinal(UInt(1)))]
        #expect(read == 9)
        let moved = store.move(at: Index<Int>(Ordinal(UInt(1))))
        #expect(moved == 9)
    }
}
