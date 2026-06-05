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

public import Storage_Primitive
import Storage_Protocol_Primitives
public import Store_Creatable_Primitives
public import Store_Primitive

// MARK: - Store.Creatable.Protocol conformance

/// `Storage.Small` is a creatable store: it vends `create(minimumCapacity:)`
/// (`Storage.Small+Create.swift` — starts inline when the request fits, spills to
/// heap otherwise) and relocates via the element-wise default
/// (`Store.Creatable+moveInitializePrefix.swift`). This is what lets a growable
/// `Buffer.Linear`/`Buffer.Ring` be backed by `Storage.Small` — growth dispatches
/// to Small's inline⊕heap allocation through the capability, no buffer-tier variant.
extension Storage.Small: Store.Creatable.`Protocol` where Element: ~Copyable {}
