import Store_Primitives
import Store_Primitives_Test_Support
import Testing

@Suite
struct `Store.Initialization` {

    @Test
    func `linear(count:) of zero is .empty`() {
        let ledger = Store.Initialization<Int>.linear(count: .zero)
        #expect(ledger == .empty)
        #expect(ledger.isEmpty)
        #expect(ledger.count == .zero)
    }

    @Test
    func `linear(count:) covers 0..<count`() {
        let ledger = Store.Initialization<Int>.linear(count: 3)
        #expect(ledger == .one(Swift.Range<Index<Int>>(start: .zero, count: 3)))
        #expect(!ledger.isEmpty)
        #expect(ledger.count == 3)
    }

    @Test
    func `.two counts both spans`() {
        let first = Swift.Range<Index<Int>>(start: .zero, count: 3)
        let second = Swift.Range<Index<Int>>(start: Index<Int>(6), count: 2)
        let ledger = Store.Initialization<Int>.two(first: first, second: second)
        #expect(ledger.count == 5)
        #expect(!ledger.isEmpty)
    }

    @Test
    func `.empty is empty`() {
        let ledger = Store.Initialization<Int>.empty
        #expect(ledger.isEmpty)
        #expect(ledger.count == .zero)
    }

    @Test
    func `isPrefixShaped is true for .empty`() {
        let ledger = Store.Initialization<Int>.empty
        #expect(ledger.isPrefixShaped)
    }

    @Test
    func `isPrefixShaped is true for .one starting at zero`() {
        let ledger = Store.Initialization<Int>.linear(count: 3)
        #expect(ledger.isPrefixShaped)
    }

    @Test
    func `isPrefixShaped is false for .one NOT starting at zero`() {
        let range = Swift.Range<Index<Int>>(start: Index<Int>(2), count: 3)
        let ledger = Store.Initialization<Int>.one(range)
        #expect(!ledger.isPrefixShaped)
    }

    @Test
    func `isPrefixShaped is false for .two (wrapped)`() {
        let first = Swift.Range<Index<Int>>(start: Index<Int>(6), count: 2)
        let second = Swift.Range<Index<Int>>(start: .zero, count: 3)
        let ledger = Store.Initialization<Int>.two(first: first, second: second)
        #expect(!ledger.isPrefixShaped)
    }

    @Test
    func `forEach visits ranges in order`() {
        let first = Swift.Range<Index<Int>>(start: .zero, count: 3)
        let second = Swift.Range<Index<Int>>(start: Index<Int>(6), count: 2)
        let ledger = Store.Initialization<Int>.two(first: first, second: second)

        var visited: [Swift.Range<Index<Int>>] = []
        ledger.forEach { visited.append($0) }
        #expect(visited == [first, second])

        var emptyVisited = 0
        Store.Initialization<Int>.empty.forEach { _ in emptyVisited += 1 }
        #expect(emptyVisited == 0)
    }

    @Test
    func `linearize packs disjoint ranges into contiguous offsets`() {

        let first = Swift.Range<Index<Int>>(start: Index<Int>(6), count: 2)
        let second = Swift.Range<Index<Int>>(start: .zero, count: 3)
        let ledger = Store.Initialization<Int>.two(first: first, second: second)

        var visits: [(Swift.Range<Index<Int>>, Index<Int>)] = []
        ledger.linearize { range, offset in visits.append((range, offset)) }

        #expect(visits.count == 2)
        #expect(visits[0].0 == first)
        #expect(visits[0].1 == .zero)
        #expect(visits[1].0 == second)
        #expect(visits[1].1 == Index<Int>(2))
    }

    @Test("Equatable distinguishes cases and payloads")
    func equatable() {
        let a = Store.Initialization<Int>.linear(count: 3)
        let b = Store.Initialization<Int>.linear(count: 3)
        let c = Store.Initialization<Int>.linear(count: 4)
        #expect(a == b)
        #expect(a != c)
        #expect(Store.Initialization<Int>.empty != a)
    }
}
