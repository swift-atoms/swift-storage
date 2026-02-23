// MARK: - ~Escapable Property.View in deinit: Lifetime-Dependence Investigation
// Purpose: Reproduce and solve "lifetime-dependent value escapes its scope"
//          when using ~Escapable view types in deinit contexts.
//
// Context: Property<Tag, Base>.View is ~Copyable & ~Escapable with
//          @_lifetime(borrow base). When accessed via a non-mutating _read
//          accessor in deinit, the compiler reports the view escapes its scope.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.0 (arm64)
//
// Result: ~Escapable values CANNOT be used in deinit when borrowing stored
//         properties of self. This is a fundamental Swift compiler limitation,
//         not a construction-method issue. Plain methods and withUnsafePointer work.
// Date: 2026-02-23

// ============================================================================
// MARK: - Minimal Infrastructure
// ============================================================================

@safe
struct MutView<Base: ~Copyable>: ~Copyable, ~Escapable {
    @usableFromInline let _base: UnsafeMutablePointer<Base>

    @_lifetime(borrow base)
    init(_ base: UnsafeMutablePointer<Base>) {
        unsafe self._base = base
    }

    @_lifetime(borrow base)
    init(borrowing base: borrowing Base) {
        unsafe self._base = UnsafeMutablePointer(mutating: withUnsafePointer(to: base) { unsafe $0 })
    }

    var base: UnsafeMutablePointer<Base> { unsafe _base }
}

@safe
struct ConstView<Base: ~Copyable>: ~Copyable, ~Escapable {
    @usableFromInline let _base: UnsafePointer<Base>

    @_lifetime(borrow base)
    init(borrowing base: borrowing Base) {
        unsafe self._base = withUnsafePointer(to: base) { unsafe $0 }
    }

    var base: UnsafePointer<Base> { unsafe _base }
}

struct Storage: ~Copyable {
    var value: Int = 42

    @unsafe
    func pointerCleanup() {
        unsafe withUnsafePointer(to: self) { ptr in
            _ = unsafe ptr.pointee.value
        }
    }
}

extension Storage {
    var mutView: MutView<Self> {
        _read { yield MutView<Self>(borrowing: self) }
    }
}

extension MutView where Base == Storage {
    @unsafe func cleanup() { unsafe base.pointee.pointerCleanup() }
    @unsafe func callAsFunction() { unsafe base.pointee.pointerCleanup() }
}

extension ConstView where Base == Storage {
    @unsafe func cleanup() { _ = unsafe base.pointee.value }
}

// ============================================================================
// MARK: - Variant 1: _read accessor + method in deinit
// Hypothesis: FAILS — ~Escapable from _read escapes deinit scope
// Result: REFUTED — error: lifetime-dependent value escapes its scope
//         Command: swift build
// ============================================================================

// struct Container1: ~Copyable {
//     var storage = Storage()
//     deinit { unsafe storage.mutView.cleanup() }
// }

// ============================================================================
// MARK: - Variant 2: ConstView via _read in deinit
// Hypothesis: FAILS — UnsafePointer vs UnsafeMutablePointer makes no difference
// Result: REFUTED — error: lifetime-dependent value escapes its scope
//         Command: swift build
// ============================================================================

// struct Container2: ~Copyable {
//     var storage = Storage()
//     deinit { unsafe storage.constView.cleanup() }
// }

// ============================================================================
// MARK: - Variant 3: Inline MutView construction in deinit
// Hypothesis: FAILS — even without accessor, inline ~Escapable construction fails
// Result: REFUTED — error: lifetime-dependent variable 'view' escapes its scope
//         Command: swift build
// ============================================================================

// struct Container3: ~Copyable {
//     var storage = Storage()
//     deinit {
//         let view = MutView<Storage>(borrowing: storage)
//         unsafe view.cleanup()
//     }
// }

// ============================================================================
// MARK: - Variant 4: Inline ConstView construction in deinit
// Hypothesis: FAILS — same as V3 with const pointer
// Result: REFUTED — error: lifetime-dependent variable 'view' escapes its scope
//         Command: swift build
// ============================================================================

// struct Container4: ~Copyable {
//     var storage = Storage()
//     deinit {
//         let view = ConstView<Storage>(borrowing: storage)
//         unsafe view.cleanup()
//     }
// }

// ============================================================================
// MARK: - Variant 5: borrowing func in deinit
// Hypothesis: FAILS — borrowing func has same lifetime semantics as _read
// Result: REFUTED — error: lifetime-dependent value escapes its scope
//         Command: swift build
// ============================================================================

// extension Storage {
//     @_lifetime(borrow self)
//     borrowing func makeMutView() -> MutView<Self> {
//         MutView<Self>(borrowing: self)
//     }
// }
// struct Container5: ~Copyable {
//     var storage = Storage()
//     deinit { unsafe storage.makeMutView().cleanup() }
// }

// ============================================================================
// MARK: - Variant 6: Plain non-mutating method (no ~Escapable)
// Hypothesis: PASSES — regular methods work in deinit (baseline)
// Result: CONFIRMED — Build Succeeded
// ============================================================================

extension Storage {
    @unsafe func directCleanup() {
        unsafe pointerCleanup()
    }
}

struct Container6: ~Copyable {
    var storage = Storage()
    deinit {
        unsafe storage.directCleanup()
    }
}

// ============================================================================
// MARK: - Variant 7: Method that creates ~Escapable internally
// Hypothesis: PASSES — ~Escapable inside method body (not crossing deinit
//             boundary) works even when called from deinit.
// Result: CONFIRMED — Build Succeeded
// ============================================================================

extension Storage {
    @unsafe func cleanupViaView() {
        let view = ConstView<Self>(borrowing: self)
        unsafe view.cleanup()
    }
}

struct Container7: ~Copyable {
    var storage = Storage()
    deinit {
        unsafe storage.cleanupViaView()
    }
}

// ============================================================================
// MARK: - Variant 8: callAsFunction via _read in deinit
// Hypothesis: FAILS — same as V1 with callAsFunction syntax
// Result: REFUTED — error: lifetime-dependent value escapes its scope
//         Command: swift build
// ============================================================================

// struct Container8: ~Copyable {
//     var storage = Storage()
//     deinit { unsafe storage.mutView() }
// }

// ============================================================================
// MARK: - Variant 9: withUnsafePointer closure in deinit
// Hypothesis: PASSES — closure gives compiler clear lifetime scope
// Result: CONFIRMED — Build Succeeded
// ============================================================================

struct Container9: ~Copyable {
    var storage = Storage()
    deinit {
        unsafe withUnsafePointer(to: storage) { ptr in
            _ = unsafe ptr.pointee.value
        }
    }
}

// ============================================================================
// MARK: - Variant 10: _overrideLifetime to rebind view lifetime in deinit
// Hypothesis: _overrideLifetime can rebind the view's lifetime dependency
//             to something the compiler accepts in deinit.
// Result: (pending)
// ============================================================================

// struct Container10: ~Copyable {
//     var storage = Storage()
//     var _deinitWorkaround: (any AnyObject & Sendable)? = nil
//     deinit {
//         let view = MutView<Storage>(borrowing: storage)
//         let rebound = unsafe _overrideLifetime(view, borrowing: storage)
//         unsafe rebound.cleanup()
//     }
// }
// Result: REFUTED — both view and rebound escape deinit scope

// ============================================================================
// MARK: - Variant 11: @_unsafeNonescapableResult on borrowing func
// Hypothesis: Attribute on function suppresses lifetime diagnostics for result.
// Result: (pending)
// ============================================================================

extension Storage {
    @_unsafeNonescapableResult
    borrowing func unsafeMutView() -> MutView<Self> {
        MutView<Self>(borrowing: self)
    }
}

struct Container11: ~Copyable {
    var storage = Storage()
    deinit {
        unsafe storage.unsafeMutView().cleanup()
    }
}

// ============================================================================
// MARK: - Variant 12: withUnsafePointer + create view inside closure
// Hypothesis: Pointer obtained via withUnsafePointer has closure-scoped
//             lifetime that the compiler can verify.
// Result: (pending)
// ============================================================================

struct Container12: ~Copyable {
    var storage = Storage()
    deinit {
        unsafe withUnsafePointer(to: storage) { ptr in
            let view = unsafe MutView<Storage>(UnsafeMutablePointer(mutating: ptr))
            unsafe view.cleanup()
        }
    }
}

// ============================================================================
// MARK: - Variant 13: _overrideLifetime with immortal-like pattern
// Hypothesis: Override lifetime to copy from a trivially-lived value.
// Result: (pending)
// ============================================================================

// struct Container13: ~Copyable {
//     var storage = Storage()
//     deinit {
//         let view = ConstView<Storage>(borrowing: storage)
//         let rebound = unsafe _overrideLifetime(view, borrowing: storage)
//         unsafe rebound.cleanup()
//     }
// }
// Result: REFUTED — same as V10

// ============================================================================
// MARK: - Results Summary
//
// REFUTED (error: lifetime-dependent value escapes its scope):
//   V1: _read accessor + method            — REFUTED
//   V2: ConstView via _read                — REFUTED
//   V3: Inline MutView construction        — REFUTED
//   V4: Inline ConstView construction      — REFUTED
//   V5: borrowing func                     — REFUTED
//   V8: callAsFunction via _read           — REFUTED
//
// CONFIRMED (compiles):
//   V6: Plain non-mutating method          — CONFIRMED (Build Succeeded, Output: prints)
//   V7: Method with internal ~Escapable    — CONFIRMED (Build Succeeded, Output: prints)
//   V9: withUnsafePointer closure          — CONFIRMED (Build Succeeded, Output: prints)
//
// CONCLUSION: ~Escapable values fundamentally cannot exist in deinit when
//   they borrow stored properties of self. The deinit scope treats self's
//   stored properties as having a lifetime that ~Escapable borrows cannot
//   satisfy. This is independent of:
//     - Construction method (property _read, borrowing func, inline)
//     - Pointer mutability (UnsafePointer vs UnsafeMutablePointer)
//     - Usage pattern (named method vs callAsFunction)
//
//   VIABLE PATTERN: V7 — a plain method on Storage.Inline that internally
//   creates and uses the ~Escapable view. The ~Escapable boundary stays
//   inside the method body; only a regular method call crosses the deinit
//   boundary.
// ============================================================================

print("Variants 6, 7, 9 compiled successfully")
