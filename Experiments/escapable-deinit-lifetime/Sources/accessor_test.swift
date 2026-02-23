// MARK: - Shared Extension for Mutating Tests

extension MutView where Base == Storage {
    @unsafe
    @_lifetime(&self)
    mutating func tracked() {
        unsafe base.pointee.value = 0
    }
}

// MARK: - Variant 14: @_unsafeNonescapableResult on _read accessor directly
// Hypothesis: Attribute on _read accessor suppresses lifetime diagnostics
//             for the yielded value, enabling use in deinit.
// Result: CRASH — Compiler assertion failure (signal 6)
//         Assertion failed: (unsafe apply result must be owned)
//         function init(unsafeApplyResult:apply:_:)
//         at LifetimeDependenceUtils.swift:173
//         While running pass #348 SILFunctionTransform
//         "LifetimeDependenceDiagnostics" on SILFunction
//         "@$s25escapable_deinit_lifetime11Container14VfD"
//         for 'deinit' (at accessor_test.swift:18:5)
//         Command: swift build
// Date: 2026-02-23

// extension Storage {
//     var unsafeView: MutView<Self> {
//         @_unsafeNonescapableResult
//         _read {
//             yield MutView<Self>(borrowing: self)
//         }
//     }
// }
//
// struct Container14: ~Copyable {
//     var storage = Storage()
//     deinit {
//         unsafe storage.unsafeView.cleanup()
//     }
// }

// MARK: - Variant 15: Non-mutating _read + mutating _modify, with attribute
// Hypothesis: Can combine @_unsafeNonescapableResult _read with regular _modify
//             for the full deinitialize pattern.
// Result: CRASH — Same assertion failure as V14 (compiler bug)

// extension Storage {
//     var deinitView: MutView<Self> {
//         @_unsafeNonescapableResult
//         _read {
//             yield MutView<Self>(borrowing: self)
//         }
//         mutating _modify {
//             var view = unsafe MutView<Self>(&self)
//             yield &view
//         }
//     }
// }
//
// struct Container15a: ~Copyable {
//     var storage = Storage()
//     deinit {
//         unsafe storage.deinitView.cleanup()
//     }
// }
//
// func testTracked15() {
//     var storage = Storage()
//     unsafe storage.deinitView.tracked()
// }

// MARK: - Variant 16: _read delegates to @_unsafeNonescapableResult borrowing func
// Hypothesis: The _read body calls a @_unsafeNonescapableResult func and yields
//             its result. The property remains the public API; the func is an
//             implementation detail. The yielded value has suppressed lifetime.
// Result: REFUTED — _read re-establishes lifetime dependence on the yielded value,
//         even though the underlying func suppressed it.
// Date: 2026-02-23

extension Storage {
    @_unsafeNonescapableResult
    borrowing func _unsafeBorrowView() -> MutView<Self> {
        MutView<Self>(borrowing: self)
    }

    var propertyView: MutView<Self> {
        _read {
            yield _unsafeBorrowView()
        }
    }
}

// struct Container16: ~Copyable {
//     var storage = Storage()
//     deinit {
//         unsafe storage.propertyView.cleanup()
//     }
// }

// MARK: - Variant 17: @_unsafeNonescapableResult on computed property getter
// Hypothesis: Attribute on the property get accessor suppresses lifetime
//             for the returned value. get (not _read) returns an owned value.
// Result: CONFIRMED — Build Succeeded
//         @_unsafeNonescapableResult on get works because get returns @owned,
//         satisfying the SIL assertion. The lifetime suppression allows deinit use.
// Date: 2026-02-23

extension Storage {
    var ownedView: MutView<Self> {
        @_unsafeNonescapableResult
        get {
            MutView<Self>(borrowing: self)
        }
    }
}

struct Container17: ~Copyable {
    var storage = Storage()
    deinit {
        unsafe storage.ownedView.cleanup()
    }
}

// MARK: - Variant 18: get + _modify combined (full deinitialize pattern)
// Hypothesis: @_unsafeNonescapableResult get works for deinit,
//             mutating _modify works for tracked operations. Both
//             under a single property name.
// Result: CONFIRMED — Build Succeeded
//         get path works in deinit; _modify path works in mutating context.
//         This is the full property-primitives pattern.
// Date: 2026-02-23

extension Storage {
    var combinedView: MutView<Self> {
        @_unsafeNonescapableResult
        get {
            MutView<Self>(borrowing: self)
        }
        mutating _modify {
            var view = unsafe MutView<Self>(&self)
            yield &view
        }
    }
}

// Test: deinit uses get path
struct Container18a: ~Copyable {
    var storage = Storage()
    deinit {
        unsafe storage.combinedView.cleanup()
    }
}

// Test: mutating context uses _modify path
func testCombinedTracked() {
    var storage = Storage()
    unsafe storage.combinedView.tracked()
}
