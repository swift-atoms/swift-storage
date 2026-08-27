import Index
import Storage
import Testing

private struct TwoSlot: Store.Ledgered.`Protocol` {
    var slots: [Int?] = [nil, nil]
    var initialization: Store.Initialization<Int> = .empty
}

extension TwoSlot {
    var capacity: Index<Int>.Count { Index<Int>.Count(UInt(2)) }

    subscript(slot: Index<Int>) -> Int {
        get { slots[Int(bitPattern: Index<Int>.Count(slot).rawValue)]! }
        set { slots[Int(bitPattern: Index<Int>.Count(slot).rawValue)] = newValue }
    }

    mutating func initialize(at slot: Index<Int>, to element: consuming Int) {
        slots[Int(bitPattern: Index<Int>.Count(slot).rawValue)] = element
    }

    mutating func move(at slot: Index<Int>) -> Int {
        let n = Int(bitPattern: Index<Int>.Count(slot).rawValue)
        defer { slots[n] = nil }

        return slots[n]!
    }
}

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
        store.initialize(at: Index<Int>(0), to: 7)
        let one = Store.Span<Int>(start: Index<Int>(0), count: .one)
        relabel(&store, to: .one(one))
        #expect(store.initialization == .one(one))
        relabel(&store, to: .empty)
        #expect(store.initialization == .empty)
    }

    @Test
    func `the refinement is a Store.Protocol (seam ops reachable through the bound)`() {
        var store = TwoSlot()
        store.unshare()
        store.initialize(at: Index<Int>(1), to: 9)
        let read = store[Index<Int>(1)]
        #expect(read == 9)
        let moved = store.move(at: Index<Int>(1))
        #expect(moved == 9)
    }
}
