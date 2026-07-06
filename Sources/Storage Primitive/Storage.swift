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

/// The Storage tier of the five-layer tower (Memory → Allocator → **Storage** → Buffer → ADT).
///
/// `Storage` is the carrier generic over the **`Allocation`** it sits on — an element-free raw byte
/// region or slot allocator (`Memory.Allocator<Memory.Heap>`,
/// `Memory.Allocator<Memory.Heap>.Pool`, …). **Typing begins here**: the allocation below is
/// element-free; the nested storage disciplines lift its raw bytes into typed `Index<Element>` slots,
/// hold the `Store.Initialization` ledger, and own the **deinit oracle** that destroys the live
/// elements before the bytes are freed.
///
/// The carrier is bound only `~Copyable` (the reference SHAPE) — **not** `& Memory.Region` — so a
/// slot allocator such as `Memory.Allocator<…>.Pool` (whose `capacity` means *slot count*, not byte
/// capacity, and therefore cannot conform `Memory.Region`) is a valid `Allocation`. Each product
/// adds its own capability constraint on its own extensions (`Memory.Region` for `Contiguous`, the
/// pool slot API for `Generational`) and caches the typed base it reads there.
///
/// The concrete storage disciplines are nested products, each Allocation-dependent and declared via
/// the cross-module nested-product pattern (`extension Storage where Allocation: ~Copyable { … }`,
/// 6.3.2 mechanic #1 — the explicit `~Copyable` clause keeps `Allocation` non-`Copyable`):
/// - `Storage.Contiguous<Element>` — single-plane dense storage (`swift-storage-primitives`).
/// - `Storage.Generational<Element>` — sparse generational storage over a stable-slot allocation
///   (`swift-storage-generational-primitives`).
/// - `Storage.Split<…>` — dual-plane lane + element storage (`swift-storage-split-primitives`).
///
/// Allocation-INDEPENDENT support (the `Store.Protocol` seam, the `Store.Initialization` ledger, the
/// generic seam algorithms) lives in non-generic homes (`swift-store-primitives` / the
/// `Storage Protocol Primitives` derivations), NOT under this generic carrier — nesting an
/// Allocation-independent type here would make it phantom-generic over `Allocation` (the W1
/// release-optimizer wall).
public struct Storage<Allocation: ~Copyable>: ~Copyable {}
