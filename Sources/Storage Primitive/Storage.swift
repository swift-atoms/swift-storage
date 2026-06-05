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

/// Namespace for storage primitives.
///
/// `Storage` provides storage disciplines with different lifecycle contracts:
///
/// | Need | Choose | Lifecycle |
/// |------|--------|-----------|
/// | Automatic cleanup, contiguous elements | `Storage.Contiguous<Memory.Heap<Element>>` (= `Storage.Contiguous<Memory.Heap<E>>`) | **Tracked** — the `Store.Initialization` ledger lives in the leaf's backing class, whose `deinit` is the cleanup oracle |
/// | Lift any tracked element store into the Storage tier | `Storage.Contiguous<M>` | **Substrate-forwarding** — the ledger is the substrate's own; `Storage.`Protocol`` exactly when `M: Store.Tracked.`Protocol`` |
/// | Stack-allocated, fixed capacity ≤256 | `Storage.Inline` | **Auto-tracked** — per-slot bit-vector tracking; consumer responsible for cleanup |
/// | Dual-array with consumer-defined metadata | `Storage.Split` | **Metadata-driven** — no tracking; consumer interprets lane metadata to determine element validity |
/// | Pool allocation with per-slot reuse | `Storage.Pool` | **Bitmap-tracked** — per-slot bit-vector tracking with automatic cleanup in `deinit` |
///
/// `Storage.Contiguous<Memory.Heap<Element>>` is, post the storage/memory split, the composition of the
/// `Storage.Contiguous` discipline over the `Memory.Heap` allocation-strategy
/// leaf (`swift-memory-heap-primitives`); the spelling is a typealias and every
/// fused-era use compiles unchanged. Each discipline is its own sibling package
/// or sub-namespace target; see `Storage Primitives Scope.md`.
public enum Storage<Element: ~Copyable> {}
