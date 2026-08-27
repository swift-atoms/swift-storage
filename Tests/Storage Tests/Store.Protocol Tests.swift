import Storage
import Index
import Testing

@safe
struct HeapStore<Element>: ~Copyable {
    @usableFromInline
    var _base: UnsafeMutablePointer<Element>

    @usableFromInline
    let _capacity: Index<Element>.Count

    @inlinable
    init(capacity: Index<Element>.Count) {
        self._capacity = capacity
        unsafe (self._base = UnsafeMutablePointer<Element>.allocate(
            capacity: Int(bitPattern: capacity.rawValue)
        ))
    }

    @inlinable
    deinit {
        unsafe _base.deallocate()
    }
}

extension HeapStore: Store.`Protocol` {
    @inlinable
    var capacity: Index<Element>.Count { _capacity }

    @inlinable
    subscript(slot: Index<Element>) -> Element {
        _read {
            yield unsafe (_base + slot).pointee
        }
        _modify {
            yield &(unsafe (_base + slot).pointee)
        }
    }

    @inlinable
    mutating func initialize(at slot: Index<Element>, to element: consuming Element) {
        unsafe (_base + slot).initialize(to: consume element)
    }

    @inlinable
    mutating func move(at slot: Index<Element>) -> Element {
        unsafe (_base + slot).move()
    }
}

struct Token: ~Copyable {
    @usableFromInline
    var value: Int

    @inlinable
    init(_ value: Int) { self.value = value }
}

@safe
struct HeapStoreNC<Element: ~Copyable>: ~Copyable {
    @usableFromInline
    var _base: UnsafeMutablePointer<Element>

    @usableFromInline
    let _capacity: Index<Element>.Count

    @inlinable
    init(capacity: Index<Element>.Count) {
        self._capacity = capacity
        unsafe (self._base = UnsafeMutablePointer<Element>.allocate(
            capacity: Int(bitPattern: capacity.rawValue)
        ))
    }

    @inlinable
    deinit {
        unsafe _base.deallocate()
    }
}

extension HeapStoreNC: Store.`Protocol` where Element: ~Copyable {
    @inlinable
    var capacity: Index<Element>.Count { _capacity }

    @inlinable
    subscript(slot: Index<Element>) -> Element {
        _read {
            yield unsafe (_base + slot).pointee
        }
        _modify {
            yield &(unsafe (_base + slot).pointee)
        }
    }

    @inlinable
    mutating func initialize(at slot: Index<Element>, to element: consuming Element) {
        unsafe (_base + slot).initialize(to: consume element)
    }

    @inlinable
    mutating func move(at slot: Index<Element>) -> Element {
        unsafe (_base + slot).move()
    }
}

func roundTrip<S: Store.`Protocol` & ~Copyable>(
    _ store: inout S,
    at slot: Index<S.Element>,
    write: S.Element,
    rewrite: S.Element
) -> S.Element where S.Element: Copyable & Equatable {
    store.initialize(at: slot, to: write)

    precondition(store[slot] == write)

    store[slot] = rewrite

    return store.move(at: slot)
}

func driveTokenSeam<S: Store.`Protocol` & ~Copyable>(
    _ store: inout S,
    at slot: Index<S.Element>,
    write: consuming S.Element,
    bump: (inout S.Element) -> Void
) -> S.Element {
    store.initialize(at: slot, to: consume write)

    bump(&store[slot])
    return store.move(at: slot)
}

@Suite struct Test {

    @Suite struct Unit {

        @Test
        func `namespace and typealias resolve`() {

            func witness<S: Store.`Protocol` & ~Copyable>(_: S.Type) {}
            witness(HeapStore<Int>.self)
            witness(HeapStoreNC<Token>.self)
        }

        @Test
        func `capacity reflects construction`() {
            let store = HeapStore<Int>(capacity: Index<Int>.Count(8))
            #expect(store.capacity == Index<Int>.Count(8))
        }

        @Test
        func `initialize then subscript-get reads the written element`() {
            var store = HeapStore<Int>(capacity: Index<Int>.Count(4))
            let slot: Index<Int> = Index(2)
            store.initialize(at: slot, to: 42)
            #expect(store[slot] == 42)

            _ = store.move(at: slot)
        }

        @Test
        func `subscript-set via _modify overwrites in place`() {
            var store = HeapStore<Int>(capacity: Index<Int>.Count(4))
            let slot: Index<Int> = Index(1)
            store.initialize(at: slot, to: 7)
            store[slot] = 99
            #expect(store[slot] == 99)
            _ = store.move(at: slot)
        }

        @Test
        func `move returns the element and leaves the slot reusable`() {
            var store = HeapStore<Int>(capacity: Index<Int>.Count(4))
            let slot: Index<Int> = Index(0)
            store.initialize(at: slot, to: 5)
            let moved = store.move(at: slot)
            #expect(moved == 5)

            store.initialize(at: slot, to: 6)
            #expect(store[slot] == 6)
            _ = store.move(at: slot)
        }
    }

    @Suite struct `Edge Case` {

        @Test
        func `first and last slots round-trip`() {
            var store = HeapStore<Int>(capacity: Index<Int>.Count(3))
            let first: Index<Int> = Index(0)
            let last: Index<Int> = Index(2)
            store.initialize(at: first, to: 100)
            store.initialize(at: last, to: 300)
            #expect(store[first] == 100)
            #expect(store[last] == 300)
            _ = store.move(at: first)
            _ = store.move(at: last)
        }

        @Test
        func `move-only element crosses the seam without copying`() {
            var store = HeapStoreNC<Token>(capacity: Index<Token>.Count(2))
            let slot: Index<Token> = Index(1)
            store.initialize(at: slot, to: Token(11))

            #expect(store[slot].value == 11)

            store[slot].value = 12
            #expect(store[slot].value == 12)

            let moved = store.move(at: slot)
            #expect(moved.value == 12)
        }
    }

    @Suite struct Integration {

        @Test
        func `generic function over the capability round-trips (Int element)`() {
            var store = HeapStore<Int>(capacity: Index<Int>.Count(4))
            let moved = roundTrip(&store, at: Index(3), write: 10, rewrite: 20)
            #expect(moved == 20)
        }

        @Test
        func `generic function drives the seam for a ~Copyable element`() {
            var store = HeapStoreNC<Token>(capacity: Index<Token>.Count(4))
            let moved = driveTokenSeam(&store, at: Index(2), write: Token(1)) { token in
                token.value += 41
            }
            #expect(moved.value == 42)
        }

        @Test
        func `generic and concrete paths agree on the moved value`() {

            var concrete = HeapStore<Int>(capacity: Index<Int>.Count(2))
            concrete.initialize(at: Index(0), to: 3)
            concrete[Index(0)] = 4
            let concreteMoved = concrete.move(at: Index(0))

            var generic = HeapStore<Int>(capacity: Index<Int>.Count(2))
            let genericMoved = roundTrip(&generic, at: Index(0), write: 3, rewrite: 4)

            #expect(concreteMoved == genericMoved)
            #expect(genericMoved == 4)
        }
    }
}
