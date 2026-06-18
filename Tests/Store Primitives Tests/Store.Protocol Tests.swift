// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Store_Primitives
import Store_Primitives_Test_Support
import Testing

// MARK: - Heap-backed conformer (Element = Int, a Copyable element)

/// A minimal heap-backed `~Copyable` conformer of `Store.`Protocol`` used to
/// exercise the four element-store requirements end-to-end. Storage is a raw
/// `UnsafeMutablePointer<Element>` region of fixed `capacity`; the per-slot
/// `_read` / `_modify` witnesses reach the element through the typed
/// `Index<Element>` pointer subscript supplied by the affine standard-library
/// integration (re-exported transitively via `Index Primitives`).
@safe
struct HeapStore<Element>: ~Copyable {
    @usableFromInline
    var _base: UnsafeMutablePointer<Element>

    @usableFromInline
    let _capacity: Index<Element>.Count

    @inlinable
    init(capacity: Index<Element>.Count) {
        self._capacity = capacity
        unsafe (self._base = UnsafeMutablePointer<Element>.allocate(capacity: Int(bitPattern: capacity)))
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
            yield unsafe _base[slot]
        }
        _modify {
            yield &(unsafe _base[slot])
        }
    }

    @inlinable
    mutating func initialize(at slot: Index<Element>, to element: consuming Element) {
        unsafe (_base + Index<Element>.Offset(_unchecked: (), slot)).initialize(to: consume element)
    }

    @inlinable
    mutating func move(at slot: Index<Element>) -> Element {
        unsafe (_base + Index<Element>.Offset(_unchecked: (), slot)).move()
    }
}

// MARK: - A move-only (~Copyable) element

/// A move-only payload. Proves the element-store seam crosses for `~Copyable`
/// elements: it can be `initialize`d into a slot, observed through the borrowing
/// `_read` accessor, mutated through the exclusive `_modify` accessor, and
/// `move`d back out — all without ever being copied.
struct Token: ~Copyable {
    @usableFromInline
    var value: Int

    @inlinable
    init(_ value: Int) { self.value = value }
}

// MARK: - Heap-backed conformer over a ~Copyable element

/// The same heap-backed conformer, declared independently so it can be
/// constrained to a `~Copyable` element. (`HeapStore` above is `Copyable`-element
/// for literal-friendly `Int` round-trips; this one carries `Element: ~Copyable`
/// to prove the seam holds when the element itself is move-only.)
@safe
struct HeapStoreNC<Element: ~Copyable>: ~Copyable {
    @usableFromInline
    var _base: UnsafeMutablePointer<Element>

    @usableFromInline
    let _capacity: Index<Element>.Count

    @inlinable
    init(capacity: Index<Element>.Count) {
        self._capacity = capacity
        unsafe (self._base = UnsafeMutablePointer<Element>.allocate(capacity: Int(bitPattern: capacity)))
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
            yield unsafe _base[slot]
        }
        _modify {
            yield &(unsafe _base[slot])
        }
    }

    @inlinable
    mutating func initialize(at slot: Index<Element>, to element: consuming Element) {
        unsafe (_base + Index<Element>.Offset(_unchecked: (), slot)).initialize(to: consume element)
    }

    @inlinable
    mutating func move(at slot: Index<Element>) -> Element {
        unsafe (_base + Index<Element>.Offset(_unchecked: (), slot)).move()
    }
}

// MARK: - Generic functions over the capability (the cross-module mutate seam)

/// A generic function constrained to `Store.`Protocol` & ~Copyable`. It mutates
/// `store` purely through the protocol surface — proving the capability is usable
/// generically without naming any concrete conformer. `Element == Int` so the body
/// can fabricate values to write.
func roundTrip<S: Store.`Protocol` & ~Copyable>(
    _ store: inout S,
    at slot: Index<S.Element>,
    write: S.Element,
    rewrite: S.Element
) -> S.Element where S.Element: Copyable & Equatable {
    store.initialize(at: slot, to: write)
    // subscript-get (borrowing _read witness)
    precondition(store[slot] == write)
    // subscript-set (exclusive _modify witness)
    store[slot] = rewrite
    // move(at:) — transfers ownership out, leaving the slot uninitialized
    return store.move(at: slot)
}

/// A generic function over a `~Copyable` element. Drives the same
/// initialize → _modify → move arc but never copies the element.
func driveTokenSeam<S: Store.`Protocol` & ~Copyable>(
    _ store: inout S,
    at slot: Index<S.Element>,
    write: consuming S.Element,
    bump: (inout S.Element) -> Void
) -> S.Element {
    store.initialize(at: slot, to: consume write)
    // exclusive _modify witness over a ~Copyable element
    bump(&store[slot])
    return store.move(at: slot)
}

// MARK: - Suite

@Suite struct Test {

    @Suite struct Unit {

        @Test
        func `namespace and typealias resolve`() {
            // Store.`Protocol` is the typealias onto the hoisted __StoreProtocol.
            // ~Copyable conformers cannot be boxed as `any`, so witness the
            // conformance through a generic constraint instead of an existential.
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
            let slot: Index<Int> = 2
            store.initialize(at: slot, to: 42)
            #expect(store[slot] == 42)
            // Clean up the one initialized slot.
            _ = store.move(at: slot)
        }

        @Test
        func `subscript-set via _modify overwrites in place`() {
            var store = HeapStore<Int>(capacity: Index<Int>.Count(4))
            let slot: Index<Int> = 1
            store.initialize(at: slot, to: 7)
            store[slot] = 99
            #expect(store[slot] == 99)
            _ = store.move(at: slot)
        }

        @Test
        func `move returns the element and leaves the slot reusable`() {
            var store = HeapStore<Int>(capacity: Index<Int>.Count(4))
            let slot: Index<Int> = 0
            store.initialize(at: slot, to: 5)
            let moved = store.move(at: slot)
            #expect(moved == 5)
            // Slot is now uninitialized — reinitialize is sound.
            store.initialize(at: slot, to: 6)
            #expect(store[slot] == 6)
            _ = store.move(at: slot)
        }
    }

    @Suite struct `Edge Case` {

        @Test
        func `first and last slots round-trip`() {
            var store = HeapStore<Int>(capacity: Index<Int>.Count(3))
            let first: Index<Int> = 0
            let last: Index<Int> = 2
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
            let slot: Index<Token> = 1
            store.initialize(at: slot, to: Token(11))
            // borrowing _read over a ~Copyable element
            #expect(store[slot].value == 11)
            // exclusive _modify over a ~Copyable element
            store[slot].value = 12
            #expect(store[slot].value == 12)
            // move the element out
            let moved = store.move(at: slot)
            #expect(moved.value == 12)
        }
    }

    @Suite struct Integration {

        @Test
        func `generic function over the capability round-trips (Int element)`() {
            var store = HeapStore<Int>(capacity: Index<Int>.Count(4))
            let moved = roundTrip(&store, at: 3, write: 10, rewrite: 20)
            #expect(moved == 20)
        }

        @Test
        func `generic function drives the seam for a ~Copyable element`() {
            var store = HeapStoreNC<Token>(capacity: Index<Token>.Count(4))
            let moved = driveTokenSeam(&store, at: 2, write: Token(1)) { token in
                token.value += 41
            }
            #expect(moved.value == 42)
        }

        @Test
        func `generic and concrete paths agree on the moved value`() {
            // Concrete path
            var concrete = HeapStore<Int>(capacity: Index<Int>.Count(2))
            concrete.initialize(at: 0, to: 3)
            concrete[0] = 4
            let concreteMoved = concrete.move(at: 0)

            // Generic path through Store.`Protocol`
            var generic = HeapStore<Int>(capacity: Index<Int>.Count(2))
            let genericMoved = roundTrip(&generic, at: 0, write: 3, rewrite: 4)

            #expect(concreteMoved == genericMoved)
            #expect(genericMoved == 4)
        }
    }
}
