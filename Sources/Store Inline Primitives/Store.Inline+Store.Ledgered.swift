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

public import Store_Ledgered_Primitives

// MARK: - Store.Ledgered.Protocol (the settable-ledger refinement)

/// The witness is the existing settable `initialization` ledger
/// (`Store.Inline+Store.Protocol.swift` — "settable so a composing discipline can
/// bulk-sync it"); this conformance NAMES the capability so the inline store serves
/// wrapped disciplines (`Buffer.Ring` over `Store.Inline`) generically (ASK-A,
/// ratified 2026-06-10).
extension Store.Inline: Store.Ledgered.`Protocol` where Element: ~Copyable {}
