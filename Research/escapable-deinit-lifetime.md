# ~Escapable Values in deinit: Lifetime-Dependence Limitation

<!--
---
version: 1.0.0
last_updated: 2026-02-23
status: DECISION
---
-->

## Context

`Storage.Inline` has no deinit — the consuming buffer type owns element cleanup (documented in `Research/inline-deinit-ownership.md`). The existing `_deinitializeTrackedSlots()` is a `public` method posing as internal API (underscore prefix).

The `Property.View(borrowing:)` change enables non-mutating `_read` accessors for `Property.View`, which seemed like the right tool to create a proper deinitialize path usable from deinit. The goal: replace `_deinitializeTrackedSlots()` with `storage.deinitialize()` via a non-mutating `_read` accessor returning `Property.View`.

## Question

Can `~Escapable` values (like `Property.View`) be used in deinit when they borrow stored properties of `self`?

## Analysis

### Experiment

`Experiments/escapable-deinit-lifetime/` tested 9 variants systematically.

### Findings

**Every construction method for `~Escapable` values fails in deinit:**

| Variant | Construction | Result |
|---------|-------------|--------|
| V1 | `_read` accessor + MutView | REFUTED |
| V2 | `_read` accessor + ConstView | REFUTED |
| V3 | Inline MutView construction | REFUTED |
| V4 | Inline ConstView construction | REFUTED |
| V5 | `borrowing func` | REFUTED |
| V8 | `_read` + `callAsFunction` | REFUTED |

The error is always: `lifetime-dependent value escapes its scope`, with deinit noted as the "parent value" whose lifetime the view depends on.

**The issue is independent of:**
- Construction method (property `_read`, `borrowing func`, inline `let`)
- Pointer mutability (`UnsafePointer` vs `UnsafeMutablePointer`)
- Usage pattern (named method vs `callAsFunction`)

**Three patterns work:**

| Variant | Pattern | Result |
|---------|---------|--------|
| V6 | Plain non-mutating method | CONFIRMED |
| V7 | Method that creates `~Escapable` internally | CONFIRMED |
| V9 | `withUnsafePointer` closure | CONFIRMED |

### Root Cause

Swift's lifetime-dependence analysis treats `self` in deinit as having a constrained lifetime scope. Any `~Escapable` value whose `@_lifetime(borrow base)` dependency chains back to a stored property of `self` is considered to "escape" the deinit scope. This is a compiler-level restriction — the analysis doesn't distinguish between "borrowed and immediately consumed" vs "borrowed and escaped."

### Key Insight: V7

Variant 7 is the most relevant: a plain method on `Storage` that internally creates a `~Escapable` view, uses it, and returns `Void`. The `~Escapable` boundary stays inside the method body. Only a regular method call crosses the deinit boundary. This means `Property.View.Read` CAN be used for the deinitialize implementation — it just can't be exposed to the deinit call site.

## Outcome

**Status**: DECISION

`~Escapable` values cannot be used in deinit as of Swift 6.2.3. This is a fundamental limitation, not a workaround-able issue. The viable pattern is V7: a non-mutating public method on `Storage.Inline` that internally constructs `Property.View.Read` for the actual work.

### Implementation Path

1. Keep the mutating `deinitialize` property accessor unchanged (for tracked operations)
2. Replace `_deinitializeTrackedSlots()` with a properly-named non-mutating method that internally uses `Property.View.Read`
3. Buffer deinits call this method
4. The naming conflict between the method and the property must be resolved (they share the `deinitialize` name domain)

### Naming Resolution

A method named `deinitialize()` would be ambiguous with the property `deinitialize` + `callAsFunction()`. Options:
- Keep the property `mutating _read` (no non-mutating `_read`) → the method `deinitialize()` is the only option in non-mutating contexts → no ambiguity in deinit
- Accept that mutating contexts where both are available may produce ambiguity errors

This needs separate naming analysis if ambiguity is unacceptable.

## References

- `Research/inline-deinit-ownership.md` — Storage.Inline has no deinit by design
- `Experiments/escapable-deinit-lifetime/` — Empirical verification
- Swift Evolution: Lifetime Dependence (SE-0456) — `@_lifetime` semantics
