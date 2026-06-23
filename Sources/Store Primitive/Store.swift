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

/// The neutral element-store substrate.
///
/// `Store` is the namespace for the ecosystem's most foundational element-access
/// capability: the ability to read, write, initialize, and move a single typed
/// element at a physical slot. It is deliberately *neutral* — it carries no
/// allocation strategy, no lifecycle policy, no layout commitment. It names only
/// the four irreducible per-slot operations that every element-addressed
/// container shares.
///
/// ## The Generic Cross-Module Mutate Seam
///
/// The element-store capability — `capacity`, the per-slot `subscript { get set }`,
/// `initialize(at:to:)`, and `move(at:)` — is the **generic cross-module mutate
/// seam**: the single set of requirements through which a generic function in one
/// module can mutate a concrete container declared in another module, and have the
/// optimizer specialize the witness calls to zero `witness_method` cross-module
/// dispatch through a multi-deep generic tower (verified on Apple Swift 6.3.2).
///
/// ## Relationship to neighbouring substrates
///
/// `Store` sits below the storage-discipline layer. The plan is:
///
/// | Layer | Role | Relationship to `Store` |
/// |-------|------|-------------------------|
/// | `Store.`Protocol`` (here) | Neutral element-store capability | The seam itself |
/// | `Storage.`Protocol`` | Single-region, slot-addressed storage disciplines | **Refines** `Store.`Protocol`` (W2) |
/// | `Storage.Contiguous` | Typed contiguous-memory access | **Conforms to** `Store.`Protocol`` (W2) |
///
/// `Store.`Protocol`` is lifted *out* of `Storage.`Protocol``'s historical
/// element-access requirements so that the seam lives in a substrate that neither
/// commits to a storage discipline nor to a memory representation — any
/// element-addressed type can adopt it.
///
/// See ``Store/`Protocol``` for the capability contract.
public enum Store {}
