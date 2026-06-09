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

public import Memory_Primitive
public import Memory_Region_Primitives

/// The Storage tier of the five-layer tower (Memory → Allocator → **Storage** → Buffer → ADT).
///
/// `Storage` is the carrier generic over the **`Allocation`** it sits on — an element-free raw byte
/// region (`Memory.Allocator<Memory.Heap>.System`, `Memory.Allocator<Memory.Inline<n>>.System`, a
/// `Pool`, …). **Typing begins here**: the allocation below is element-free; the nested storage
/// disciplines lift its raw bytes into typed `Index<Element>` slots, hold the `Store.Initialization`
/// ledger, and own the **deinit oracle** that destroys the live elements before the bytes are freed.
///
/// The concrete storage disciplines are nested products, each Allocation-dependent and declared via
/// the cross-module nested-product pattern (`extension Storage where Allocation: ~Copyable { … }`,
/// 6.3.2 mechanic #1 — the explicit `~Copyable` clause keeps `Allocation` non-`Copyable`):
/// - `Storage.Contiguous<Element>` — single-plane dense storage (`swift-storage-primitives`).
/// - `Storage.Generational<Element>` — sparse generational storage over a stable-slot allocation
///   (`swift-storage-arena-primitives`).
/// - `Storage.Split<…>` — dual-plane lane + element storage (`swift-storage-split-primitives`).
///
/// Allocation-INDEPENDENT support (the `Store.Protocol` seam, the `Store.Initialization` ledger, the
/// generic seam algorithms) lives in non-generic homes (`swift-store-primitives` / the
/// `Storage Protocol Primitives` derivations), NOT under this generic carrier — nesting an
/// Allocation-independent type here would make it phantom-generic over `Allocation` (the W1
/// release-optimizer wall).
public struct Storage<Allocation: ~Copyable & Memory.Region>: ~Copyable {}
