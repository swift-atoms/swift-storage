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

public import Memory_Region_Primitives
public import Store_Ledgered_Primitives

// MARK: - Store.Ledgered.Protocol (the settable-ledger refinement)

/// The witness is the existing settable `initialization` ledger
/// (`Storage.Contiguous.swift` — "settable so a composing discipline can bulk-sync it");
/// this conformance merely NAMES the capability so a discipline whose occupancy is not
/// prefix-shaped (`Buffer.Ring`) can sync it generically (ASK-A, ratified 2026-06-10).
extension Storage.Contiguous: Store.Ledgered.`Protocol`
where Allocation: Memory.Region & ~Copyable, Element: ~Copyable {}
